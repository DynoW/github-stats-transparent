const std = @import("std");
const HttpClient = @import("http_client.zig");

repositories: []Repository,
contributed_repos: []ContributedRepo = &.{},
user: []const u8,
name: []const u8,
repo_contributions: u32 = 0,
issue_contributions: u32 = 0,
commit_contributions: u32 = 0,
pr_contributions: u32 = 0,
prs_merged: u32 = 0,
review_contributions: u32 = 0,

const Statistics = @This();

const Repository = struct {
    name: []const u8,
    stars: u32,
    forks: u32,
    languages: ?[]Language,
    views: u32,
    private: bool,
    is_fork: bool = false,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.languages) |languages| {
            for (languages) |language| {
                language.deinit(allocator);
            }
            allocator.free(languages);
        }
    }

};

const ContributedRepo = struct {
    name: []const u8,
    private: bool,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

const Language = struct {
    name: []const u8,
    size: u32,
    color: ?[]const u8 = null,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.color) |color| allocator.free(color);
    }
};

pub fn init(
    client: *HttpClient,
    allocator: std.mem.Allocator,
) !Statistics {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var self: Statistics = try getRepos(allocator, &arena, client);
    errdefer self.deinit(allocator);
    return self;
}

pub fn initFromJson(allocator: std.mem.Allocator, s: []const u8) !Statistics {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = try std.json.parseFromSliceLeaky(
        Statistics,
        arena.allocator(),
        s,
        .{ .ignore_unknown_fields = true },
    );
    return try deepcopy(allocator, parsed);
}

pub fn deinit(self: Statistics, allocator: std.mem.Allocator) void {
    for (self.repositories) |repository| {
        repository.deinit(allocator);
    }
    allocator.free(self.repositories);
    for (self.contributed_repos) |repository| {
        repository.deinit(allocator);
    }
    allocator.free(self.contributed_repos);
    allocator.free(self.user);
    allocator.free(self.name);
}

fn getBasicInfo(client: *HttpClient, arena: *std.heap.ArenaAllocator) !struct {
    years: []u32,
    user: []const u8,
    name: ?[]const u8,
} {
    std.log.info("Getting contribution years...", .{});
    const response = try client.graphql(
        \\query {
        \\  viewer {
        \\    login
        \\    name
        \\    contributionsCollection {
        \\      contributionYears
        \\    }
        \\  }
        \\}
    , null);
    defer client.allocator.free(response.body);
    if (response.status != .ok) {
        std.log.err(
            "Failed to get contribution years ({?s})",
            .{response.status.phrase()},
        );
        return error.RequestFailed;
    }
    const parsed = (try std.json.parseFromSliceLeaky(
        struct { data: struct { viewer: struct {
            login: []const u8,
            name: ?[]const u8,
            contributionsCollection: struct {
                contributionYears: []u32,
            },
        } } },
        arena.allocator(),
        response.body,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    )).data.viewer;

    return .{
        .years = parsed.contributionsCollection.contributionYears,
        .user = parsed.login,
        .name = parsed.name,
    };
}

fn getOwnedRepos(
    allocator: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    client: *HttpClient,
) ![]Repository {
    var repositories: std.ArrayList(Repository) =
        try .initCapacity(allocator, 32);
    errdefer {
        for (repositories.items) |repo| {
            repo.deinit(allocator);
        }
        repositories.deinit(allocator);
    }

    var cursor: ?[]const u8 = null;
    while (true) {
        std.log.info("Getting owned repositories...", .{});
        const response = try client.graphql(
            \\query ($after: String) {
            \\  viewer {
            \\    repositories(
            \\        first: 100,
            \\        affiliations: [OWNER],
            \\        orderBy: { field: UPDATED_AT, direction: DESC },
            \\        after: $after
            \\    ) {
            \\      pageInfo {
            \\        hasNextPage
            \\        endCursor
            \\      }
            \\      nodes {
            \\        nameWithOwner
            \\        stargazerCount
            \\        forkCount
            \\        isPrivate
            \\        isFork
            \\        languages(
            \\            first: 100,
            \\            orderBy: { direction: DESC, field: SIZE }
            \\        ) {
            \\          edges {
            \\            size
            \\            node {
            \\              name
            \\              color
            \\            }
            \\          }
            \\        }
            \\      }
            \\    }
            \\  }
            \\}
        ,
            .{ .after = cursor },
        );
        defer client.allocator.free(response.body);
        if (response.status != .ok) {
            std.log.err(
                "Failed to get owned repositories ({?s})",
                .{response.status.phrase()},
            );
            return error.RequestFailed;
        }
        const page = (try std.json.parseFromSliceLeaky(
            struct { data: struct { viewer: struct {
                repositories: struct {
                    pageInfo: struct {
                        hasNextPage: bool,
                        endCursor: ?[]const u8,
                    },
                    nodes: []struct {
                        nameWithOwner: []const u8,
                        stargazerCount: u32,
                        forkCount: u32,
                        isPrivate: bool,
                        isFork: bool,
                        languages: ?struct {
                            edges: ?[]struct {
                                size: u32,
                                node: struct {
                                    name: []const u8,
                                    color: ?[]const u8,
                                },
                            },
                        },
                    },
                },
            } } },
            arena.allocator(),
            response.body,
            .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
        )).data.viewer.repositories;
        std.log.info(
            "Parsed {d} owned repositories",
            .{page.nodes.len},
        );

        for (page.nodes) |raw_repo| {
            var repository = Repository{
                .name = try allocator.dupe(u8, raw_repo.nameWithOwner),
                .stars = raw_repo.stargazerCount,
                .forks = raw_repo.forkCount,
                .private = raw_repo.isPrivate,
                .is_fork = raw_repo.isFork,
                .languages = null,
                .views = 0,
            };
            errdefer repository.deinit(allocator);
            if (raw_repo.languages) |repo_languages| {
                if (repo_languages.edges) |raw_languages| {
                    repository.languages = try allocator.alloc(
                        Language,
                        raw_languages.len,
                    );
                    errdefer {
                        allocator.free(repository.languages.?);
                        repository.languages = null;
                    }
                    for (
                        raw_languages,
                        repository.languages.?,
                        0..,
                    ) |raw, *language, i| {
                        errdefer {
                            for (0..i, repository.languages.?) |_, l| {
                                allocator.free(l.name);
                                if (l.color) |c| allocator.free(c);
                            }
                        }
                        language.* = .{
                            .name = try allocator.dupe(u8, raw.node.name),
                            .size = raw.size,
                        };
                        errdefer allocator.free(language.name);
                        if (raw.node.color) |color| {
                            language.color = try allocator.dupe(u8, color);
                        }
                        errdefer if (language.color) |c| allocator.free(c);
                    }
                }
            }

            std.log.info(
                "Getting views for {s}...",
                .{raw_repo.nameWithOwner},
            );
            const response2 = try client.rest(
                try std.mem.concat(
                    arena.allocator(),
                    u8,
                    &.{
                        "https://api.github.com/repos/",
                        raw_repo.nameWithOwner,
                        "/traffic/views",
                    },
                ),
            );
            defer client.allocator.free(response2.body);
            if (response2.status == .ok) {
                repository.views = (try std.json.parseFromSliceLeaky(
                    struct { count: u32 },
                    arena.allocator(),
                    response2.body,
                    .{ .ignore_unknown_fields = true },
                )).count;
            } else {
                std.log.info(
                    "Failed to get views for {s} ({?s})",
                    .{ raw_repo.nameWithOwner, response2.status.phrase() },
                );
            }

            try repositories.append(allocator, repository);
        }

        if (page.pageInfo.hasNextPage) {
            cursor = page.pageInfo.endCursor;
        } else {
            break;
        }
    }

    return try repositories.toOwnedSlice(allocator);
}

fn getContributionsByYear(
    context: struct {
        allocator: std.mem.Allocator,
        arena: *std.heap.ArenaAllocator,
        client: *HttpClient,
        result: *Statistics,
        seen: *std.StringHashMap(bool),
        contributed: *std.ArrayList(ContributedRepo),
    },
    year: usize,
    start_month: usize,
    months: usize,
) !void {
    std.log.info(
        "Getting {d} month{s} of data starting from {d}/{d}...",
        .{ months, if (months != 1) "s" else "", start_month + 1, year },
    );
    const response = try context.client.graphql(
        \\query ($from: DateTime, $to: DateTime) {
        \\  viewer {
        \\    contributionsCollection(from: $from, to: $to) {
        \\      totalRepositoryContributions
        \\      totalIssueContributions
        \\      totalCommitContributions
        \\      totalPullRequestContributions
        \\      totalPullRequestReviewContributions
        \\      commitContributionsByRepository(maxRepositories: 100) {
        \\        repository {
        \\          nameWithOwner
        \\          isPrivate
        \\        }
        \\      }
        \\    }
        \\  }
        \\}
    ,
        .{
            .from = try std.fmt.allocPrint(
                context.arena.allocator(),
                "{d}-{d:02}-01T00:00:00Z",
                .{ year, start_month + 1 },
            ),
            .to = try std.fmt.allocPrint(
                context.arena.allocator(),
                "{d}-{d:02}-01T00:00:00Z",
                .{
                    year + (start_month + months) / 12,
                    (start_month + months) % 12 + 1,
                },
            ),
        },
    );
    defer context.client.allocator.free(response.body);
    if (response.status != .ok) {
        std.log.err(
            "Failed to get data from {d} ({?s})",
            .{ year, response.status.phrase() },
        );
        return error.RequestFailed;
    }
    const stats = (try std.json.parseFromSliceLeaky(
        struct { data: struct { viewer: struct {
            contributionsCollection: struct {
                totalRepositoryContributions: u32,
                totalIssueContributions: u32,
                totalCommitContributions: u32,
                totalPullRequestContributions: u32,
                totalPullRequestReviewContributions: u32,
                commitContributionsByRepository: []struct {
                    repository: struct {
                        nameWithOwner: []const u8,
                        isPrivate: bool,
                    },
                },
            },
        } } },
        context.arena.allocator(),
        response.body,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    )).data.viewer.contributionsCollection;
    std.log.info(
        "Parsed {d} total repositories from {d}",
        .{ stats.commitContributionsByRepository.len, year },
    );

    const limit = 100;
    // This slightly convoluted logic subdivides the months range for the
    // current call. It assumes the initial months range is 12, and subdivides
    // by increasingly large prime factors of 12. If it cannot divide by any
    // prime factors of 12, the size of the range is 1. In that case, it emits a
    // warning and proceeds with processing the data.
    if (stats.commitContributionsByRepository.len >= limit) {
        for (&[_]usize{ 2, 3 }) |factor| {
            if (months % factor == 0) {
                for (0..factor) |i| {
                    try getContributionsByYear(
                        context,
                        year,
                        start_month + (months / factor) * i,
                        months / factor,
                    );
                }
                return;
            }
        } else {
            std.log.warn(
                "More than {d} repos returned for {d}/{d}. " ++
                    "Some data may be omitted due to GitHub API limitations.",
                .{ limit, start_month + 1, year },
            );
        }
    }

    context.result.repo_contributions += stats.totalRepositoryContributions;
    context.result.issue_contributions += stats.totalIssueContributions;
    context.result.commit_contributions += stats.totalCommitContributions;
    context.result.pr_contributions += stats.totalPullRequestContributions;
    context.result.review_contributions +=
        stats.totalPullRequestReviewContributions;

    for (stats.commitContributionsByRepository) |x| {
        const name = x.repository.nameWithOwner;
        if (context.seen.get(name) orelse false) {
            continue;
        }
        try context.seen.put(name, true);
        const name_dup = try context.allocator.dupe(u8, name);
        errdefer context.allocator.free(name_dup);
        try context.contributed.append(context.allocator, .{
            .name = name_dup,
            .private = x.repository.isPrivate,
        });
    }
}

fn getRepos(
    allocator: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    client: *HttpClient,
) !Statistics {
    var result: Statistics = .{
        .user = undefined,
        .name = undefined,
        .repositories = undefined,
        .contributed_repos = undefined,
    };
    var contributed: std.ArrayList(ContributedRepo) =
        try .initCapacity(allocator, 32);
    errdefer {
        for (contributed.items) |repo| {
            repo.deinit(allocator);
        }
        contributed.deinit(allocator);
    }
    var seen: std.StringHashMap(bool) = .init(arena.allocator());
    defer seen.deinit();

    const info = try getBasicInfo(client, arena);
    if (info.name) |n| {
        std.log.info("Getting data for {s} ({s})...", .{ n, info.user });
    } else {
        std.log.info("Getting data for user {s}...", .{info.user});
    }

    result.user = try allocator.dupe(u8, info.user);
    errdefer allocator.free(result.user);
    result.name = try allocator.dupe(u8, info.name orelse info.user);
    errdefer allocator.free(result.name);

    result.repositories = try getOwnedRepos(allocator, arena, client);
    errdefer {
        for (result.repositories) |repository| {
            repository.deinit(allocator);
        }
        allocator.free(result.repositories);
    }

    result.prs_merged = try getPrsMerged(client, arena, info.user);

    for (info.years) |year| {
        try getContributionsByYear(.{
            .allocator = allocator,
            .arena = arena,
            .client = client,
            .result = &result,
            .seen = &seen,
            .contributed = &contributed,
        }, year, 0, 12);
    }

    result.contributed_repos = try contributed.toOwnedSlice(allocator);
    errdefer {
        for (result.contributed_repos) |repository| {
            repository.deinit(allocator);
        }
        allocator.free(result.contributed_repos);
    }
    std.sort.pdq(Repository, result.repositories, {}, struct {
        pub fn lessThanFn(_: void, lhs: Repository, rhs: Repository) bool {
            if (rhs.views == lhs.views) {
                return rhs.stars + rhs.forks < lhs.stars + lhs.forks;
            }
            return rhs.views < lhs.views;
        }
    }.lessThanFn);

    return result;
}

fn getPrsMerged(client: *HttpClient, arena: *std.heap.ArenaAllocator, user: []const u8) !u32 {
    std.log.info("Getting merged PR count for {s}...", .{user});
    const response = try client.graphql(
        \\query ($query: String!) {
        \\  search(query: $query, type: ISSUE, first: 1) {
        \\    issueCount
        \\  }
        \\}
    ,
        .{
            .query = try std.fmt.allocPrint(
                arena.allocator(),
                "author:{s} is:pr is:merged",
                .{user},
            ),
        },
    );
    defer client.allocator.free(response.body);
    if (response.status != .ok) {
        std.log.err("Failed to get merged PR count ({?s})", .{response.status.phrase()});
        return error.RequestFailed;
    }
    const parsed = try std.json.parseFromSliceLeaky(
        struct { data: struct { search: struct { issueCount: u32 } } },
        arena.allocator(),
        response.body,
        .{ .ignore_unknown_fields = true },
    );
    return parsed.data.search.issueCount;
}


// May not correctly free memory if there are errors during copying
fn deepcopy(a: std.mem.Allocator, o: anytype) !@TypeOf(o) {
    return switch (@typeInfo(@TypeOf(o))) {
        .pointer => |p| switch (p.size) {
            .slice => v: {
                const result = try a.dupe(p.child, o);
                errdefer a.free(result);
                for (o, result) |src, *dest| {
                    dest.* = try deepcopy(a, src);
                }
                break :v result;
            },
            // Only slices in this struct
            else => comptime unreachable,
        },
        .@"struct" => |s| v: {
            var result = o;
            inline for (s.fields) |field| {
                @field(result, field.name) =
                    try deepcopy(a, @field(o, field.name));
            }
            break :v result;
        },
        .optional => if (o) |v| try deepcopy(a, v) else null,
        else => o,
    };
}
