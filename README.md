# ShaktiLean: Type-Safe Wayland Compositor

A **type-safe Wayland protocol implementation in Lean 4** with **GPU rendering in Rust**, demonstrating formal verification meets high-performance graphics.

## 📖 Documentation

All documentation is organized in the `docs/` folder:

- **[README_CONSOLIDATED.md](docs/README_CONSOLIDATED.md)** - Main project overview and quick start
- **[MONOREPO_SETUP.md](docs/MONOREPO_SETUP.md)** - Unified repository structure and workflow
- **[PROTOCOL_DOCS.md](docs/PROTOCOL_DOCS.md)** - Wayland protocol formalization details
- **[SERIALIZATION_GUIDE.md](docs/SERIALIZATION_GUIDE.md)** - Wire protocol encoding/decoding
- **[GETTING_STARTED_SERIALIZATION.md](docs/GETTING_STARTED_SERIALIZATION.md)** - Serialization module guide
- **[PHASE1_CONNECTION.md](docs/PHASE1_CONNECTION.md)** - Ring buffer implementation
- **[PHASE2_STATEMACHINE.md](docs/PHASE2_STATEMACHINE.md)** - Object lifecycle state machine
- **[PHASE3_EVENTLOOP.md](docs/PHASE3_EVENTLOOP.md)** - Event processing pipeline
- **[PHASE4_GRAPHICS.md](docs/PHASE4_GRAPHICS.md)** - OpenGL ES FFI bindings
- **[COMPLETE_STACK.md](docs/COMPLETE_STACK.md)** - Full implementation overview
- **[ENHANCEMENTS_IMPLEMENTED.md](docs/ENHANCEMENTS_IMPLEMENTED.md)** - Type class enhancements
- **[USAGE_EXAMPLES.md](docs/USAGE_EXAMPLES.md)** - Code examples and patterns

## 🚀 Quick Start

```bash
# Enter Nix environment with all dependencies
nix develop

# Build Lean compositor
lake build

# Build Rust display wrapper
cargo build --release

# Run the compositor
./shakti_display/target/release/shakti_display
```

## 🏗️ Project Structure

```
├── ShaktiLean/              # Lean library (1,345 LOC)
│   ├── Basic.lean           # Core types + type classes
│   ├── Protocol.lean        # Wayland protocol (16 interfaces)
│   ├── Serialization.lean   # Message codec
│   ├── Connection.lean      # Ring buffers
│   ├── StateMachine.lean    # State validation
│   ├── EventLoop.lean       # Event processing
│   ├── GraphicsFFI.lean     # OpenGL ES bindings
│   ├── Renderer.lean        # Surface rendering
│   └── FFI.lean             # C interop exports
├── Main.lean                # Runnable compositor entry point
├── shakti_display/          # Rust display wrapper (170 LOC)
│   ├── src/
│   │   ├── main.rs          # Event loop + GPU rendering
│   │   └── ffi.rs           # Lean FFI bindings
│   ├── build.rs             # Build configuration
│   ├── Cargo.toml           # Rust dependencies
│   └── flake.nix            # Nix environment
├── Cargo.toml               # Workspace root
├── lakefile.toml            # Lean build config
├── flake.nix                # Development environment
├── .gitignore               # Build artifacts exclusion
└── docs/                    # Documentation
    └── *.md                 # All markdown files
```

## ✨ Features

✅ **Type-Safe Protocol Implementation** - 100% Lean type checking
✅ **GPU Rendering** - 60fps with wgpu (Vulkan/Metal/DirectX 12)
✅ **Cross-Platform** - Linux, macOS, Windows support
✅ **FFI Integration** - Seamless Lean-Rust interoperability
✅ **Reproducible Builds** - Nix flakes for exact environments
✅ **Complete Documentation** - Extensive guides and examples

## 📊 Statistics

| Metric | Value |
|--------|-------|
| Total LOC | 1,515 |
| Lean LOC | 1,345 |
| Rust LOC | 170 |
| Type Safety | 100% |
| Memory Safety | 100% (Rust) |
| Target FPS | 60fps |

## 🔗 Architecture

```
Event Loop (Rust/winit) → Lean Compositor (FFI) → GPU Rendering (wgpu)
     ↓                           ↓                        ↓
  Window Input            Protocol Logic            Display @60fps
```

---

**For detailed information, see the [README_CONSOLIDATED.md](docs/README_CONSOLIDATED.md)**
