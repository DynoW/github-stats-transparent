const std = @import("std");

var is_installed: ?bool = null;

pub fn isInstalled(gpa: std.mem.Allocator, io: std.Io) bool {
    if (is_installed) |v| {
        return v;
    }
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const run = std.process.run(arena.allocator(), io, .{
        .argv = &.{ "git", "--version" },
    }) catch {
        is_installed = false;
        return is_installed.?;
    };
    is_installed = switch (run.term) {
        .exited => |v| v == 0,
        else => false,
    };
    return is_installed.?;
}

pub fn currentCommit(gpa: std.mem.Allocator, io: std.Io) ![]const u8 {
    if (!isInstalled(gpa, io)) return error.GitNotInstalled;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const run = try std.process.run(arena.allocator(), io, .{
        .argv = &.{ "git", "rev-parse", "HEAD" },
    });
    return try gpa.dupe(u8, run.stdout[0..8]);
}

