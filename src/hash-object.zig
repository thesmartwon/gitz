const std = @import("std");
const clap = @import("clap");
const Repo = @import("./repo.zig");

const params = clap.parseParamsComptime(
    \\-h, --help                 Display this help and exit.
    \\-t <type>                  Type of object to be created
    \\-w                         Write object to database
    \\<file>...
    \\
);
pub const otype = enum {
    commit,
    tree,
    blob,
    tag,
};
const parsers = .{
    .type = clap.parsers.enumeration(otype),
    .file = clap.parsers.string,
};
pub const Args = clap.ResultEx(clap.Help, &params, &parsers);

pub fn main(
    io: std.Io,
    gpa: std.mem.Allocator,
    iter: *std.process.Args.Iterator,
) !void {
    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, &parsers, iter, .{
        .diagnostic = &diag,
        .allocator = gpa,
    }) catch |err| {
        try diag.reportToFile(io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0 or res.positionals.len == 0) {
        try clap.helpToFile(io, .stderr(), clap.Help, &params, .{});
        return;
    }

    // const t = res.args.t orelse .blob;

    // if (res.args.w) {
    //     const repo = try Repo.open(io, gpa, res);
    //     defer repo.deinit(gpa);
    // }

    // const stdout = std.Io.File.stdout();
    const cwd = std.Io.Dir.cwd();
    var fbuf: [std.heap.pageSize()]u8 = undefined;

    for (res.positionals[0]) |p| {
        var hasher = std.crypto.hash.Sha1.init(.{});

        const f = try cwd.openFile(io, p, .{});
        defer f.close(io);

        const stat = try f.stat(io);
        const sig = try std.fmt.bufPrint(&fbuf, "blob {d}\x00", .{ stat.size });
        hasher.update(sig);

        var freader = f.reader(io, &fbuf);
        var hashed = std.Io.Reader.hashed(&freader.interface, &hasher, &fbuf);
        try hashed.reader.discardAll(stat.size);

        var sha1: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
        hasher.final(&sha1);
        std.debug.print("{x}\n", .{sha1});
    }
}
