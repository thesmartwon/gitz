git_dir: []const u8,
// For worktrees or submodules
common_dir: []const u8,
prefix: []const u8,

config: Config,

// By default, git config will read configuration options from multiple files:
//
//      $(prefix)/etc/gitconfig
//          System-wide configuration file.
//
//                                                                                  $XDG_CONFIG_HOME/git/config, ~/.gitconfig
//          User-specific configuration files. When the XDG_CONFIG_HOME environment variable  is  not  set  or  empty,
//          $HOME/.config/ is used as $XDG_CONFIG_HOME.
//
//          These  are also called "global" configuration files. If both files exist, both files are read in the order
//          given above.
//
//      $GIT_DIR/config
//          Repository specific configuration file.
//
//      $GIT_DIR/config.worktree
//          This is optional and is only searched when extensions.worktreeConfig is present in $GIT_DIR/config.
//
//      You may also provide additional configuration parameters when running any git command by using the -c  option.
//      See git(1) for details.
//
//      Options  will  be read from all of these files that are available. If the global or the system-wide configura‐
//      tion files are missing or unreadable they will be ignored. If the repository configuration file is missing  or
//      unreadable,  git  config will exit with a non-zero error code. An error message is produced if the file is un‐
//      readable, but not if it is missing.
//
//      The files are read in the order given above, with last value found taking precedence over values read earlier.
//      When multiple values are taken then all values of a key from all files will be used.
//
//      By default, options are only written to the repository specific configuration file. Note that  this  also  af‐
//      fects options like set and unset. git config will only ever change one file at a time.
//
//      You  can  limit  which configuration sources are read from or written to by specifying the path of a file with
//      the --file option, or by specifying a configuration scope with --system, --global, --local, or --worktree. For
//      more, see the section called “OPTIONS” above.
const Config = struct {
    repository_format_version: u0 = 0,
    file_mode: bool = true,
    bare: bool = false,
    log_all_ref_updates: bool = true,

    pub fn write(self: @This(), io: std.Io, git_dir: std.Io.Dir) !void {
        const f = try git_dir.createFile(io, "config", .{});
        try f.writeStreamingAll(io, "[core]\n");

        inline for (std.meta.fields(@TypeOf(self))) |field| {
            try f.writeStreamingAll(io, "\t");
            try f.writeStreamingAll(io, field.name);
            try f.writeStreamingAll(io, " = ");

            const value = @field(self, field.name);

            switch (field.type) {
                u0 => {
                    try f.writeStreamingAll(io, "0");
                },
                bool => {
                    try f.writeStreamingAll(io, if (value) "true" else "false");
                },
                else => |t| @compileError("implement " ++ t.name),
            }
            try f.writeStreamingAll(io, "\n");
        }
    }
};

pub fn init(io: std.Io, gpa: std.mem.Allocator, args: Args) !@This() {
    const cwd = std.Io.Dir.cwd();
    const git_dir_path = try std.fs.path.resolve(gpa, &.{ args.positionals[0] orelse ".", ".git" });
    const config: Config = .{};

    {
        // init common directories
        try std.Io.Dir.createDirPath(cwd, io, git_dir_path);
        const git_dir = try std.Io.Dir.openDir(cwd, io, git_dir_path, .{});
        defer std.Io.Dir.close(git_dir, io);
        try config.write(io, git_dir);
    }

    return .{
        .git_dir = git_dir_path,
        .common_dir = "",
        .prefix = "",
        .config = config,
    };
}

pub fn deinit(self: @This(), gpa: std.mem.Allocator) void {
    gpa.free(self.git_dir);
    gpa.free(self.common_dir);
    gpa.free(self.prefix);
}

const std = @import("std");
const Args = @import("./init.zig").Args;
