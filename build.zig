const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the main pauliz module
    const pauliz_mod = b.createModule(.{
        .root_source_file = b.path("src/pauliz.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Export module for dependents
    _ = b.addModule("pauliz", .{
        .root_source_file = b.path("src/pauliz.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = pauliz_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/integration.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    integration_tests.root_module.addImport("pauliz", pauliz_mod);
    const run_integration_tests = b.addRunArtifact(integration_tests);
    test_step.dependOn(&run_integration_tests.step);

    // Example: Bell state
    const bell_mod = b.createModule(.{
        .root_source_file = b.path("examples/bell_state.zig"),
        .target = target,
        .optimize = optimize,
    });
    bell_mod.addImport("pauliz", pauliz_mod);

    const bell_example = b.addExecutable(.{
        .name = "bell_state",
        .root_module = bell_mod,
    });
    b.installArtifact(bell_example);

    const run_bell = b.addRunArtifact(bell_example);
    const bell_step = b.step("bell", "Run Bell state example");
    bell_step.dependOn(&run_bell.step);
}
