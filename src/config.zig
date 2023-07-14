//! Raw configuration values.
//!
//! Code which needs these values should use `constants.zig` instead.
//! Configuration values are set from a combination of:
//! - default values
//! - `root.tigerbeetle_config`
//! - `@import("tigerbeetle_options")`

const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;

const root = @import("root");

const BuildOptions = struct {
    config_base: ConfigBase,
    config_log_level: std.log.Level,
    tracer_backend: TracerBackend,
    hash_log_mode: HashLogMode,
    config_aof_record: bool,
    config_aof_recovery: bool,
};

// Allow setting build-time config either via `build.zig` `Options`, or via a struct in the root
// file.
const build_options: BuildOptions = blk: {
    if (@hasDecl(root, "vsr_options")) {
        break :blk root.vsr_options;
    } else {
        const vsr_options = @import("vsr_options");
        // Zig's `addOptions` reuses the type, but redeclares it — identical structurally,
        // but a different type from a nominal typing perspective.
        var result: BuildOptions = undefined;
        for (std.meta.fields(BuildOptions)) |field| {
            @field(result, field.name) = launder_type(
                field.field_type,
                @field(vsr_options, field.name),
            );
        }
        break :blk result;
    }
};

fn launder_type(comptime T: type, comptime value: anytype) T {
    if (T == bool) {
        return value;
    }
    if (@typeInfo(T) == .Enum) {
        assert(@typeInfo(@TypeOf(value)) == .Enum);
        return @field(T, @tagName(value));
    }
    undefined;
}

const vsr = @import("vsr.zig");
const sector_size = @import("constants.zig").sector_size;

pub const Config = struct {
    pub const Cluster = ConfigCluster;
    pub const Process = ConfigProcess;

    cluster: ConfigCluster,
    process: ConfigProcess,
};

/// Configurations which are tunable per-replica (or per-client).
/// - Replica configs need not equal each other.
/// - Client configs need not equal each other.
/// - Client configs need not equal replica configs.
/// - Replica configs can change between restarts.
///
/// Fields are documented within constants.zig.
const ConfigProcess = struct {
    log_level: std.log.Level = .info,
    tracer_backend: TracerBackend = .none,
    hash_log_mode: HashLogMode = .none,
    verify: bool,
    port: u16 = 3001,
    address: []const u8 = "127.0.0.1",
    memory_size_max_default: u64 = 1024 * 1024 * 1024,
    cache_accounts_size_default: usize,
    cache_transfers_size_default: usize,
    cache_transfers_posted_size_default: usize,
    client_request_queue_max: usize = 32,
    lsm_manifest_node_size: usize = 16 * 1024,
    connection_delay_min_ms: u64 = 50,
    connection_delay_max_ms: u64 = 1000,
    tcp_backlog: u31 = 64,
    tcp_rcvbuf: c_int = 4 * 1024 * 1024,
    tcp_keepalive: bool = true,
    tcp_keepidle: c_int = 5,
    tcp_keepintvl: c_int = 4,
    tcp_keepcnt: c_int = 3,
    tcp_nodelay: bool = true,
    direct_io: bool,
    direct_io_required: bool,
    journal_iops_read_max: usize = 8,
    journal_iops_write_max: usize = 8,
    client_replies_iops_read_max: usize = 1,
    client_replies_iops_write_max: usize = 2,
    tick_ms: u63 = 10,
    rtt_ms: u64 = 300,
    rtt_multiple: u8 = 2,
    backoff_min_ms: u64 = 100,
    backoff_max_ms: u64 = 10000,
    clock_offset_tolerance_max_ms: u64 = 10000,
    clock_epoch_max_ms: u64 = 60000,
    clock_synchronization_window_min_ms: u64 = 2000,
    clock_synchronization_window_max_ms: u64 = 20000,
    grid_iops_read_max: u64 = 16,
    grid_iops_write_max: u64 = 16,
    grid_repair_request_max: usize = 8,
    grid_repair_reads_max: usize = 8,
    grid_repair_writes_max: usize = 8,
    grid_cache_size_default: u64 = 1024 * 1024 * 1024,
    aof_record: bool = false,
    aof_recovery: bool = false,
    /// When null, this defaults to message_body_size_max.
    sync_trailer_message_body_size_max: ?usize = null,
};

/// Configurations which are tunable per-cluster.
/// - All replicas within a cluster must have the same configuration.
/// - Replicas must reuse the same configuration when the binary is upgraded — they do not change
///   over the cluster lifetime.
/// - The storage formats generated by different ConfigClusters are incompatible.
///
/// Fields are documented within constants.zig.
const ConfigCluster = struct {
    cache_line_size: comptime_int = 64,
    clients_max: usize,
    pipeline_prepare_queue_max: usize = 8,
    view_change_headers_suffix_max: usize = 8 + 1,
    quorum_replication_max: u8 = 3,
    journal_slot_count: usize = 1024,
    message_size_max: usize = 1 * 1024 * 1024,
    superblock_copies: comptime_int = 4,
    storage_size_max: u64 = 16 * 1024 * 1024 * 1024 * 1024,
    block_size: comptime_int = 64 * 1024,
    lsm_levels: u7 = 7,
    lsm_growth_factor: u32 = 8,
    lsm_batch_multiple: comptime_int = 64,
    lsm_snapshots_max: usize = 32,
    lsm_value_to_key_layout_ratio_min: comptime_int = 16,

    /// The WAL requires at least two sectors of redundant headers — otherwise we could lose them all to
    /// a single torn write. A replica needs at least one valid redundant header to determine an
    /// (untrusted) maximum op in recover_torn_prepare(), without which it cannot truncate a torn
    /// prepare.
    pub const journal_slot_count_min = 2 * @divExact(sector_size, @sizeOf(vsr.Header));

    pub const clients_max_min = 1;

    /// The smallest possible message_size_max (for use in the simulator to improve performance).
    /// The message body must have room for pipeline_prepare_queue_max headers in the DVC.
    pub fn message_size_max_min(clients_max: usize) usize {
        return std.math.max(
            sector_size,
            std.mem.alignForward(
                @sizeOf(vsr.Header) + clients_max * @sizeOf(vsr.Header),
                sector_size,
            ),
        );
    }

    /// Fingerprint of the cluster-wide configuration.
    /// It is used to assert that all cluster members share the same config.
    pub fn checksum(comptime config: ConfigCluster) u128 {
        @setEvalBranchQuota(10_000);
        var hasher = std.crypto.hash.Blake3.init(.{});
        inline for (std.meta.fields(ConfigCluster)) |field| {
            const value = @field(config, field.name);
            const value_64 = @as(u64, value);
            hasher.update(std.mem.asBytes(&value_64));
        }
        var target: [32]u8 = undefined;
        hasher.final(&target);
        return @bitCast(u128, target[0..@sizeOf(u128)].*);
    }
};

pub const ConfigBase = enum {
    production,
    development,
    test_min,
    default,
};

pub const TracerBackend = enum {
    none,
    // Sends data to https://github.com/wolfpld/tracy.
    tracy,
};

pub const HashLogMode = enum {
    none,
    create,
    check,
};

pub const configs = struct {
    /// A good default config for production.
    pub const default_production = Config{
        .process = .{
            .direct_io = true,
            .direct_io_required = true,
            .cache_accounts_size_default = @sizeOf(vsr.tigerbeetle.Account) * 1024 * 1024,
            .cache_transfers_size_default = 0,
            .cache_transfers_posted_size_default = @sizeOf(u256) * 256 * 1024,
            .verify = false,
        },
        .cluster = .{
            .clients_max = 32,
        },
    };

    /// A good default config for local development.
    /// (For production, use default_production instead.)
    /// The cluster-config is compatible with the default production config.
    pub const default_development = Config{
        .process = .{
            .direct_io = true,
            .direct_io_required = false,
            .cache_accounts_size_default = @sizeOf(vsr.tigerbeetle.Account) * 1024 * 1024,
            .cache_transfers_size_default = 0,
            .cache_transfers_posted_size_default = @sizeOf(u256) * 256 * 1024,
            .verify = true,
        },
        .cluster = default_production.cluster,
    };

    /// Minimal test configuration — small WAL, small grid block size, etc.
    /// Not suitable for production, but good for testing code that would be otherwise hard to reach.
    pub const test_min = Config{
        .process = .{
            .direct_io = false,
            .direct_io_required = false,
            .cache_accounts_size_default = @sizeOf(vsr.tigerbeetle.Account) * 2048,
            .cache_transfers_size_default = 0,
            .cache_transfers_posted_size_default = @sizeOf(u256) * 2048,
            .grid_repair_request_max = 4,
            .grid_repair_reads_max = 4,
            .grid_repair_writes_max = 1,
            .verify = true,
            // Set to a small value to ensure the multipart trailer sync is easily tested.
            .sync_trailer_message_body_size_max = 129,
        },
        .cluster = .{
            .clients_max = 4 + 3,
            .pipeline_prepare_queue_max = 4,
            .view_change_headers_suffix_max = 4 + 1,
            .journal_slot_count = Config.Cluster.journal_slot_count_min,
            .message_size_max = Config.Cluster.message_size_max_min(4),
            .storage_size_max = 200 * 1024 * 1024,

            .block_size = sector_size,
            .lsm_batch_multiple = 4,
            .lsm_growth_factor = 4,
        },
    };

    /// Mostly-minimal configuration, with a higher storage limit to ensure that the fuzzers are
    /// able to max out the LSM levels.
    pub const fuzz_min = config: {
        var base = test_min;
        base.cluster.storage_size_max = 4 * 1024 * 1024 * 1024;
        break :config base;
    };

    const default = if (@hasDecl(root, "tigerbeetle_config"))
        root.tigerbeetle_config
    else if (builtin.is_test)
        test_min
    else
        default_development;

    pub const current = current: {
        var base = switch (build_options.config_base) {
            .default => default,
            .production => default_production,
            .development => default_development,
            .test_min => test_min,
        };

        // TODO Use additional build options to overwrite other fields.
        base.process.log_level = build_options.config_log_level;
        base.process.tracer_backend = build_options.tracer_backend;
        base.process.hash_log_mode = build_options.hash_log_mode;
        base.process.aof_record = build_options.config_aof_record;
        base.process.aof_recovery = build_options.config_aof_recovery;

        break :current base;
    };
};
