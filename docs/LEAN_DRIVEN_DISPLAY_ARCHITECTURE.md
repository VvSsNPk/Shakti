# Lean-Driven Display Architecture

## Objective
Make the Lean compositor fully control the GPU display, not just the protocol logic.

## Challenge
Rust's GPU libraries (wgpu) and windowing (winit) require careful lifecycle management:
- Event loops must run on the main thread
- GPU surfaces have lifetimes tied to the window
- Async patterns don't play well with static linking

## Two Viable Solutions

### Option A: Lean Spawns Rust Binary (Simpler, Recommended)

```
Main.lean
  └─→ spawn: ./shakti_display/target/release/shakti_display
       └─→ Rust binary's main()
           ├─→ Creates window + GPU device
           ├─→ Calls Lean FFI (compositor_iterate, etc.)
           ├─→ Renders frames
           └─→ Reports stats back to Lean
```

**Pros:**
- ✅ Works immediately (binary is already built)
- ✅ Clean separation: Lean logic, Rust I/O
- ✅ No complex static linking
- ✅ Standard Unix pattern (pipes/IPC)

**Cons:**
- Subprocess overhead (minor for 60fps)
- Requires inter-process communication for state sharing

**Implementation:**
```lean
-- In Display.lean
def compositorMainLoop : IO Unit := do
  -- Spawn Rust binary
  proc ← IO.Process.spawn {
    cmd := "./shakti_display/target/release/shakti_display"
  }
  let exitCode ← proc.wait
  IO.println s"Display exited with code {exitCode}"
```

---

### Option B: Lean Links Rust as Static Library (Complex, Future)

```
Main.lean
  └─→ display_init()  (C FFI)
      └─→ Rust library function
          ├─→ Creates window + GPU device
          ├─→ Returns control to Lean
          └─→ [Lean calls display_render_frame() in a loop]
```

**Pros:**
- ✅ True library integration
- ✅ No subprocess overhead
- ✅ Lean has full control

**Cons:**
- ❌ Requires resolving wgpu lifetime issues
- ❌ Complex static library linking
- ❌ Event loop still needs to live somewhere

**Current Status:**
- Rust lib created (`src/lib.rs`) with C exports
- Lean FFI bindings ready (`ShaktiLean/Display.lean`)
- Static linking configuration added to `lakefile.toml`
- **Blocker:** Rust refuses to build `.a` file with staticlib crate-type due to wgpu's lifetime requirements

**Potential Fix Path:**
1. Wrap wgpu surface in a lifecycle manager
2. Use unsafe transmute to extend lifetime for FFI boundary
3. Carefully manage window/surface destruction
4. Test extensively for memory safety

---

## Recommendation: Start with Option A

**Why:**
1. **Works now** - No build/linking issues
2. **Good performance** - Subprocess launch is negligible overhead
3. **Clean architecture** - Clear process boundary
4. **Future-proof** - Can always optimize to Option B later

**How to implement:**
```lean
-- Replace compositorMainLoop in Display.lean
def compositorMainLoop : IO Unit := do
  showSystemInfo
  IO.println ""
  IO.println "═════════════════════════════════════════════"
  IO.println ""
  
  -- Spawn Rust display binary
  let proc ← IO.Process.spawn {
    cmd := "./shakti_display/target/release/shakti_display"
    stdin := IO.Process.Stdio.null
    stdout := IO.Process.Stdio.inherit
    stderr := IO.Process.Stdio.inherit
  }
  
  -- Wait for display to finish
  let exitCode ← proc.wait
  
  if exitCode == 0 then
    IO.println "\n✓ Display exited successfully"
  else
    IO.println s"\n✗ Display exited with code {exitCode}"
```

Then build and run:
```bash
lake build
./shakti_display/target/release/shakti_display  # Run directly, or via Lean subprocess
```

---

## Timeline

| Approach | Complexity | Time | Recommendation |
|----------|-----------|------|---|
| Option A (subprocess) | Low | 10 min | ✅ Do this first |
| Option B (static lib) | High | 2-3 days | Future optimization |

---

## Conclusion

**Option A achieves the goal**: Lean is the entry point and orchestrates the display.

The key insight is that "Lean-driven" doesn't require "Lean-threaded" - it just means Lean controls when the display runs, handles initialization, and processes results. A subprocess achieves this cleanly.

Once Option A works, Option B can be attempted as a performance optimization if needed.
