const std = @import("std");
const testing = std.testing;

pub const AEffect = extern struct {
    pub const Magic: i32 = ('V' << 24) | ('s' << 16) | ('t' << 8) | 'P';

    /// Magic bytes required to identify a VST Plugin
    magic: i32 = Magic,

    /// Host to Plugin Dispatcher
    dispatcher: DispatcherCallback,

    /// Deprecated in VST 2.4
    deprecated_process: ProcessCallback = deprecatedProcessCallback,

    setParameter: SetParameterCallback,

    getParameter: GetParameterCallback,

    num_programs: i32,

    num_params: i32,

    num_inputs: i32,

    num_outputs: i32,

    flags: i32,

    reserved1: isize = 0,

    reserved2: isize = 0,

    initial_delay: i32,

    _real_qualities: i32 = 0,

    _off_qualities: i32 = 0,

    _io_ratio: i32 = 0,

    object: ?*c_void = null,

    user: ?*c_void = null,

    unique_id: i32,

    version: i32,

    processReplacing: ProcessCallback,

    processReplacingF64: ProcessCallbackF64,

    future: [56]u8 = [_]u8{0} ** 56,

    fn deprecatedProcessCallback(effect: *AEffect, inputs: [*][*]f32, outputs: [*][*]f32, sample_frames: i32) callconv(.C) void {}
};

test "AEffect" {
    try testing.expectEqual(@as(i32, 0x56737450), AEffect.Magic);
}

pub const Codes = struct {
    pub const HostToPlugin = enum(i32) {
        Initialize = 0,
        Shutdown = 1,
        GetCurrentPresetNum = 3,
        GetProductName = 48,
        GetVendorName = 47,
        GetInputInfo = 33,
        GetOutputInfo = 34,
        GetCategory = 35,
        GetTailSize = 52,
        GetApiVersion = 58,
        SetSampleRate = 10,
        SetBufferSize = 11,
        StateChange = 12,
        GetMidiInputs = 78,
        GetMidiOutputs = 79,
        GetMidiKeyName = 66,
        StartProcess = 71,
        StopProcess = 72,
        GetPresetName = 29,
        CanDo = 51,
        GetVendorVersion = 49,
        GetEffectName = 45,
        EditorGetRect = 13,
        EditorOpen = 14,
        EditorClose = 15,
        ChangePreset = 2,
        GetCurrentPresetName = 5,
        GetParameterLabel = 6,
        GetParameterDisplay = 7,
        GetParameterName = 8,
        CanBeAutomated = 26,
        EditorIdle = 19,
        EditorKeyDown = 59,
        EditorKeyUp = 60,
        ProcessEvents = 25,

        pub fn toInt(self: HostToPlugin) i32 {
            return @enumToInt(self);
        }

        pub fn fromInt(int: anytype) !HostToPlugin {
            return std.meta.intToEnum(HostToPlugin, int);
        }
    };

    pub const PluginToHost = enum(i32) {
        GetVersion = 1,
        IOChanged = 13,
        GetSampleRate = 16,
        GetBufferSize = 17,
        GetVendorString = 32,

        pub fn toInt(self: PluginToHost) i32 {
            return @enumToInt(self);
        }

        pub fn fromInt(int: anytype) !PluginToHost {
            return std.meta.intToEnum(HostToPlugin, int);
        }
    };
};

pub const Plugin = struct {
    pub const Flag = enum(i32) {
        HasEditor = 1,
        CanReplacing = 1 << 4,
        ProgramChunks = 1 << 5,
        IsSynth = 1 << 8,
        NoSoundInStop = 1 << 9,
        CanDoubleReplacing = 1 << 12,

        pub fn toI32(self: Flag) i32 {
            return @intCast(i32, @enumToInt(self));
        }

        pub fn toBitmask(flags: []const Flag) i32 {
            var result: i32 = 0;

            for (flags) |flag| {
                result = result | flag.toI32();
            }

            return result;
        }
    };

    pub const Category = enum {
        Unknown,
        Effect,
        Synthesizer,
        Analysis,
        Mastering,
        Spacializer,
        RoomFx,
        SurroundFx,
        Restoration,
        OfflineProcess,
        Shell,
        Generator,

        pub fn toI32(self: Category) i32 {
            return @intCast(i32, @enumToInt(self));
        }
    };
};

pub const Rect = extern struct {
    top: i16,
    left: i16,
    bottom: i16,
    right: i16,
};

pub const ProductNameMaxLength = 64;
pub const VendorNameMaxLength = 64;
pub const ParamMaxLength = 32;

pub const PluginMain = fn (
    callback: HostCallback,
) callconv(.C) ?*AEffect;

pub const HostCallback = fn (
    effect: *AEffect,
    opcode: i32,
    index: i32,
    value: isize,
    ptr: ?*c_void,
    opt: f32,
) callconv(.C) isize;

pub const DispatcherCallback = fn (
    effect: *AEffect,
    opcode: i32,
    index: i32,
    value: isize,
    ptr: ?*c_void,
    opt: f32,
) callconv(.C) isize;

pub const ProcessCallback = fn (
    effect: *AEffect,
    inputs: [*][*]f32,
    outputs: [*][*]f32,
    sample_frames: i32,
) callconv(.C) void;

pub const ProcessCallbackF64 = fn (
    effect: *AEffect,
    inputs: [*][*]f64,
    outputs: [*][*]f64,
    sample_frames: i32,
) callconv(.C) void;

pub const SetParameterCallback = fn (
    effect: *AEffect,
    index: i32,
    parameter: f32,
) callconv(.C) void;

pub const GetParameterCallback = fn (
    effect: *AEffect,
    index: i32,
) callconv(.C) f32;

/// This is should eventually replace HostToPlugin.Code.
/// Like everything in this library it is subject to change and not yet final.
pub const HighLevelCode = union(enum) {
    SetSampleRate: f32,
    GetProductName: [*:0]u8,
    GetVendorName: [*:0]u8,
    GetPresetName: [*:0]u8,
    GetApiVersion: void,
    SetBufferSize: isize,
    ProcessEvents: *const VstEvents,
    EditorGetRect: *?*Rect,
    EditorOpen: void,
    EditorClose: void,
    GetTailSize: void,

    pub fn parseOpCode(opcode: i32) ?std.meta.Tag(HighLevelCode) {
        const tag: std.meta.Tag(HighLevelCode) = switch (opcode) {
            10 => .SetSampleRate,
            11 => .SetBufferSize,
            25 => .ProcessEvents,
            else => return null,
        };

        return tag;
    }

    pub fn parse(
        opcode: i32,
        index: i32,
        value: isize,
        ptr: ?*c_void,
        opt: f32,
    ) ?HighLevelCode {
        return switch (opcode) {
            10 => .{ .SetSampleRate = opt },
            11 => .{ .SetBufferSize = value },

            13 => .{ .EditorGetRect = @ptrCast(*?*Rect, @alignCast(@alignOf(*?*Rect), ptr)) },
            14 => .{ .EditorOpen = {} },
            15 => .{ .EditorClose = {} },

            25 => .{ .ProcessEvents = @ptrCast(*VstEvents, @alignCast(@alignOf(VstEvents), ptr)) },

            29 => .{ .GetPresetName = @ptrCast([*:0]u8, ptr) },

            47 => .{ .GetVendorName = @ptrCast([*:0]u8, ptr) },
            48 => .{ .GetProductName = @ptrCast([*:0]u8, ptr) },

            else => return null,
        };
    }
};

pub const VstEvents = struct {
    num_events: i32,
    reserved: *isize,
    events: [*]VstEvent,

    pub fn iterate(self: *const VstEvents) Iterator {
        return .{ .index = 0, .ptr = self };
    }

    pub const Iterator = struct {
        index: usize,
        ptr: *const VstEvents,

        pub fn next(self: *Iterator) ?VstEvent {
            if (self.index >= self.ptr.num_events) {
                return null;
            }

            const ev = self.ptr.events[self.index];
            self.index += 1;
            return ev;
        }
    };
};

pub const VstEvent = struct {
    pub const Type = enum {
        midi = 1,
        audio = 2,
        video = 3,
        parameter = 4,
        trigger = 5,
        sysex = 6,
    };

    typ: Type,
    byte_size: i32,
    delta_frames: i32,
    flags: i32,
    data: [16]u8,
};

pub const Event = union(enum) {
    Midi: struct {
        flags: i32,
        note_length: i32,
        note_offset: i32,
        data: [4]u8,
        detune: i8,
        note_off_velocity: u8,
    },

    pub fn parse(event: VstEvent) Event {
        switch (event.typ) {
            .midi => {
                const raw = @ptrCast(*const RawVstMidiEvent, &event);

                return Event{ .Midi = .{
                    .flags = raw.flags,
                    .note_length = raw.note_length,
                    .note_offset = raw.note_offset,
                    .data = raw.midi_data,
                    .detune = raw.detune,
                    .note_off_velocity = raw.note_off_velocity,
                } };
            },
            .sysex => unreachable, // TODO
            else => unreachable,
        }
    }
};

pub const MidiFlags = enum(i32) {
    is_realtime = 1 << 0,
};

pub const RawVstMidiEvent = struct {
    typ: VstEvent.Type,
    byte_size: i32,
    delta_frames: i32,
    flags: i32,
    note_length: i32,
    note_offset: i32,
    midi_data: [4]u8,
    detune: i8,
    note_off_velocity: u8,
    reserved: [2]u8,
};
