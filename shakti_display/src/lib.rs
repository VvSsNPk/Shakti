use std::sync::Mutex;
use std::time::{Duration, Instant};
use wgpu::*;
use winit::event_loop::EventLoop;
use winit::window::{Window, WindowBuilder};

mod ffi;
use ffi::{CompositorFFI, RendererFFI};

const WINDOW_WIDTH: u32 = 1920;
const WINDOW_HEIGHT: u32 = 1080;

pub struct DisplayState {
    device: Device,
    queue: Queue,
    surface: Surface<'static>,
    config: SurfaceConfiguration,
    compositor: CompositorFFI,
    renderer: RendererFFI,
    frame_count: u64,
    last_fps_time: Instant,
    start_time: Instant,
}

// Global display state
static DISPLAY_STATE: Mutex<Option<DisplayState>> = Mutex::new(None);

/// Initialize the display (call once at startup)
#[no_mangle]
pub extern "C" fn display_init() -> u32 {
    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        pollster::block_on(init_display_internal())
    })) {
        Ok(true) => 1,
        _ => 0,
    }
}

async fn init_display_internal() -> bool {
    println!("\n╔════════════════════════════════════════╗");
    println!("║   ShaktiLean Compositor Display       ║");
    println!("║   (Rust + wgpu + winit)               ║");
    println!("╚════════════════════════════════════════╝\n");

    let event_loop = match EventLoop::new() {
        Ok(el) => el,
        Err(_) => return false,
    };

    let window = Box::leak(Box::new(
        match WindowBuilder::new()
            .with_title("ShaktiLean Compositor - Black Screen")
            .with_inner_size(winit::dpi::PhysicalSize::new(WINDOW_WIDTH, WINDOW_HEIGHT))
            .build(&event_loop)
        {
            Ok(w) => w,
            Err(_) => return false,
        },
    ));

    println!("✓ Window created ({}x{})", WINDOW_WIDTH, WINDOW_HEIGHT);

    let instance = Instance::new(Default::default());

    let surface = match unsafe { instance.create_surface(window) } {
        Ok(s) => s,
        Err(_) => return false,
    };

    let adapter = match instance
        .request_adapter(&RequestAdapterOptions {
            power_preference: PowerPreference::HighPerformance,
            compatible_surface: Some(&surface),
            force_fallback_adapter: false,
        })
        .await
    {
        Some(a) => a,
        None => return false,
    };

    println!("GPU: {}", adapter.get_info().name);

    let (device, queue) = match adapter
        .request_device(&DeviceDescriptor::default(), None)
        .await
    {
        Ok((d, q)) => (d, q),
        Err(_) => return false,
    };

    let caps = surface.get_capabilities(&adapter);
    let format = caps
        .formats
        .iter()
        .copied()
        .find(|f| f.is_srgb())
        .unwrap_or(caps.formats[0]);

    let config = SurfaceConfiguration {
        usage: TextureUsages::RENDER_ATTACHMENT,
        format,
        width: WINDOW_WIDTH,
        height: WINDOW_HEIGHT,
        present_mode: PresentMode::AutoVsync,
        alpha_mode: CompositeAlphaMode::Auto,
        view_formats: vec![],
        desired_maximum_frame_latency: 2,
    };
    surface.configure(&device, &config);

    println!("✓ GPU initialized and configured");

    let mut compositor = CompositorFFI::new();
    let mut renderer = RendererFFI::new();
    let (major, minor, _) = CompositorFFI::version();

    println!("\n╔════════════════════════════════════════╗");
    println!("║   Lean Compositor Integration (FFI)   ║");
    println!("╚════════════════════════════════════════╝");
    if compositor.is_ready() {
        println!("✓ Compositor initialized (v{}.{})", major, minor);
    } else {
        println!("⚠ Compositor not ready");
    }
    println!("✓ Renderer initialized");
    println!("\nStarting integrated render loop...\n");

    // Event loop is only needed for window creation, can be dropped now
    drop(event_loop);

    let state = DisplayState {
        device,
        queue,
        surface,
        config,
        compositor,
        renderer,
        frame_count: 0,
        last_fps_time: Instant::now(),
        start_time: Instant::now(),
    };

    match DISPLAY_STATE.lock() {
        Ok(mut guard) => {
            *guard = Some(state);
            true
        }
        Err(_) => false,
    }
}

/// Render a single frame
#[no_mangle]
pub extern "C" fn display_render_frame() -> u32 {
    match DISPLAY_STATE.lock() {
        Ok(mut guard) => match guard.as_mut() {
            Some(state) => {
                state.compositor.iterate();
                state.renderer.iterate();

                match state.surface.get_current_texture() {
                    Ok(output) => {
                        let view = output.texture.create_view(&Default::default());
                        let mut encoder =
                            state.device.create_command_encoder(&Default::default());

                        {
                            let _render_pass = encoder.begin_render_pass(&RenderPassDescriptor {
                                label: Some("render_pass"),
                                color_attachments: &[Some(RenderPassColorAttachment {
                                    view: &view,
                                    resolve_target: None,
                                    ops: Operations {
                                        load: LoadOp::Clear(Color::BLACK),
                                        store: StoreOp::Store,
                                    },
                                })],
                                depth_stencil_attachment: None,
                                timestamp_writes: None,
                                occlusion_query_set: None,
                            });
                        }

                        state.queue.submit(std::iter::once(encoder.finish()));
                        output.present();
                        state.frame_count += 1;

                        if state.last_fps_time.elapsed() >= Duration::from_secs(1) {
                            let fps = state.renderer.get_fps();
                            let renderer_frames = state.renderer.get_frame_number();
                            println!(
                                "  FPS: {} | Renderer frames: {} | GPU frames: {}",
                                fps, renderer_frames, state.frame_count
                            );
                            state.last_fps_time = Instant::now();
                        }
                        1
                    }
                    Err(SurfaceError::Lost) => {
                        state.surface.configure(&state.device, &state.config);
                        1
                    }
                    Err(SurfaceError::OutOfMemory) => {
                        println!("Out of memory!");
                        0
                    }
                    Err(e) => {
                        eprintln!("Surface error: {e:?}");
                        0
                    }
                }
            }
            None => 0,
        },
        Err(_) => 0,
    }
}

/// Get the total frame count
#[no_mangle]
pub extern "C" fn display_get_frame_count() -> u64 {
    match DISPLAY_STATE.lock() {
        Ok(guard) => match guard.as_ref() {
            Some(state) => state.frame_count,
            None => 0,
        },
        Err(_) => 0,
    }
}

/// Get elapsed time in milliseconds
#[no_mangle]
pub extern "C" fn display_get_elapsed_ms() -> u64 {
    match DISPLAY_STATE.lock() {
        Ok(guard) => match guard.as_ref() {
            Some(state) => state.start_time.elapsed().as_millis() as u64,
            None => 0,
        },
        Err(_) => 0,
    }
}

/// Cleanup (call once at shutdown)
#[no_mangle]
pub extern "C" fn display_shutdown() {
    match DISPLAY_STATE.lock() {
        Ok(mut guard) => {
            if let Some(state) = guard.take() {
                println!(
                    "\n✓ Display closed\n✓ Frames rendered: {}\n✓ Runtime: {:.2}s\nShaktiLean integrated compositor shutdown.\n",
                    state.frame_count,
                    state.start_time.elapsed().as_secs_f32()
                );
            }
        }
        Err(_) => {}
    }
}
