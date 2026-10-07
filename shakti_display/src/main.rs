use std::time::{Duration, Instant};
use wgpu::*;
use winit::event::{Event, WindowEvent};
use winit::event_loop::EventLoop;
use winit::window::WindowBuilder;

mod ffi;
use ffi::{CompositorFFI, RendererFFI};

const WINDOW_WIDTH: u32 = 1920;
const WINDOW_HEIGHT: u32 = 1080;

fn main() {
    pollster::block_on(run());
}

async fn run() {
    println!("\n╔════════════════════════════════════════╗");
    println!("║   ShaktiLean Compositor Display       ║");
    println!("║   (Rust + wgpu + winit)               ║");
    println!("╚════════════════════════════════════════╝\n");

    let event_loop = EventLoop::new().unwrap();
    let window = Box::leak(Box::new(
        WindowBuilder::new()
            .with_title("ShaktiLean Compositor - Black Screen")
            .with_inner_size(winit::dpi::PhysicalSize::new(WINDOW_WIDTH, WINDOW_HEIGHT))
            .build(&event_loop)
            .expect("Failed to create window"),
    ));

    println!("✓ Window created ({}x{})", WINDOW_WIDTH, WINDOW_HEIGHT);

    let instance = Instance::new(Default::default());

    let surface = unsafe {
        instance.create_surface(window)
    }.expect("Failed to create surface");

    let adapter = instance
        .request_adapter(&RequestAdapterOptions {
            power_preference: PowerPreference::HighPerformance,
            compatible_surface: Some(&surface),
            force_fallback_adapter: false,
        })
        .await
        .expect("Failed to find GPU adapter");

    println!("GPU: {}", adapter.get_info().name);

    let (device, queue) = adapter
        .request_device(&DeviceDescriptor::default(), None)
        .await
        .expect("Failed to create device");

    let caps = surface.get_capabilities(&adapter);
    let format = caps
        .formats
        .iter()
        .copied()
        .find(|f| f.is_srgb())
        .unwrap_or(caps.formats[0]);

    let mut config = SurfaceConfiguration {
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

    // Initialize Lean FFI components
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

    let start = Instant::now();
    let mut frame_count = 0u64;
    let mut last_fps = Instant::now();

    event_loop
        .run(move |event, target| {
            match event {
                Event::WindowEvent { event, .. } => match event {
                    WindowEvent::CloseRequested => {
                        println!("\n✓ Window closed");
                        println!("✓ Frames rendered: {}", frame_count);
                        println!("✓ Compositor runtime: {}ms", compositor.get_frame_time());
                        println!("✓ Runtime: {:.2}s", start.elapsed().as_secs_f32());
                        println!("\nShaktiLean integrated compositor shutdown.\n");
                        target.exit();
                    }
                    WindowEvent::Resized(size) => {
                        config.width = size.width;
                        config.height = size.height;
                        surface.configure(&device, &config);
                    }
                    _ => {}
                },
                Event::AboutToWait => {
                    // Update Lean compositor state
                    compositor.iterate();
                    renderer.iterate();

                    // Render using wgpu
                    match surface.get_current_texture() {
                        Ok(output) => {
                            let view = output.texture.create_view(&Default::default());
                            let mut encoder = device.create_command_encoder(&Default::default());

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

                            queue.submit(std::iter::once(encoder.finish()));
                            output.present();
                            frame_count += 1;

                            if last_fps.elapsed() >= Duration::from_secs(1) {
                                let fps = renderer.get_fps();
                                let renderer_frames = renderer.get_frame_number();
                                println!("  FPS: {} | Renderer frames: {} | GPU frames: {}",
                                    fps, renderer_frames, frame_count);
                                last_fps = Instant::now();
                            }
                        }
                        Err(SurfaceError::Lost) => {
                            surface.configure(&device, &config);
                        }
                        Err(SurfaceError::OutOfMemory) => {
                            println!("Out of memory!");
                            target.exit();
                        }
                        Err(e) => eprintln!("Surface error: {e:?}"),
                    }
                }
                _ => {}
            }
        })
        .unwrap();
}
