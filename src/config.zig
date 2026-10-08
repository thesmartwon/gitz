const std = @import("std");
const clap = @import("clap");
const Repo = @import("./repo.zig");

const params = clap.parseParamsComptime(
    \\-h, --help                 Display this help and exit.
    // \\--bare                     Create a bare repository.
    // \\--object-format <oformat>  Add the two numbers
    // \\--ref-format    <rformat>  Subtract the two numbers
    // \\-b, --initial-branch <str>
    \\<directory>
    \\
);
const parsers = .{
    .directory = clap.parsers.string,
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

    if (res.args.help != 0 or res.positionals.len > 1) {
        try clap.helpToFile(io, .stderr(), clap.Help, &params, .{});
        return;
    }

    const repo = try Repo.open(io, gpa);
    defer repo.deinit(gpa);

    const stdout = std.Io.File.stdout();
    var fbuf: [std.heap.pageSize()]u8 = undefined;
    var fwriter = stdout.writer(io, &fbuf);
    const writer = &fwriter.interface;
    defer fwriter.flush() catch {};

    try writer.print("{f}\n", .{ std.json.fmt(repo.config, .{}) });
}
