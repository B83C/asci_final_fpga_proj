use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicU8, Ordering};
use std::sync::mpsc::sync_channel;
use std::sync::{self, Arc, mpsc};
use std::thread::{self, sleep};
use std::time::Duration;

use asic::TopVga;
use clap::Parser;
use doublebuf::DoubleBuf;
use macroquad::prelude::*;
use marlin::verilator::tracing::Waveform;
use marlin::verilator::{AsDynamicVerilatedModel, VerilatorRuntime, VerilatorRuntimeOptions};
use marlin::verilog::prelude::*;

use snafu::{ResultExt, Whatever};

#[derive(Parser)]
pub struct Args {
    #[clap(long)]
    dump_vcd: bool,
    #[clap(long)]
    num_frames: Option<u32>,
    #[clap(long)]
    num_ticks: Option<u32>,
}

fn window_conf() -> Conf {
    Conf {
        window_title: "VGA Display".to_owned(),
        window_width: 1280,
        window_height: 720,
        window_resizable: false,
        ..Default::default()
    }
}

// #[hotpath::measure]
#[macroquad::main(window_conf)]
#[hotpath::main]
#[snafu::report]
async fn main() -> Result<(), Whatever> {
    let args = Args::parse();

    const W: usize = 1280;
    const H: usize = 720;

    let (trigger_exit, should_exit) = sync_channel(0);
    let buttons_state = Arc::new(AtomicU8::new(0xF));

    let (update_frame, receive_frame) = sync_channel(0);
    let (return_frame, collect_frame) = sync_channel(0);
    let sim_dump_vcd = args.dump_vcd;
    let sim_num_frames = args.num_frames;
    let sim_num_ticks = args.num_ticks;
    let sim_buttons = buttons_state.clone();
    let leds_state = Arc::new(AtomicU8::new(0));
    let sim_leds = leds_state.clone();

    let mut bytes = vec![255u8; W * H * 4];
    // let bytes = ArcSwap::new(Arc::new([255u8; W * H * 4]));
    let texture = Texture2D::from_rgba8(W as u16, H as u16, &bytes);

    thread::spawn(move || {
        let runtime = VerilatorRuntime::new(
            &Path::new("build"),
            &["src/top.sv".as_ref()],
            &["src".as_ref()],
            [],
            VerilatorRuntimeOptions::default(),
        )
        .unwrap();

        let mut top = runtime
            .create_model::<TopVga>(&marlin::verilator::VerilatedModelConfig {
                enable_tracing: sim_dump_vcd.then_some(Waveform::Fst),
                verilator_optimization: 3,
                ignored_warnings: vec!["fatal".into(), "lint".into()],
                ..Default::default()
            })
            .unwrap();

        std::fs::write(
            "build/surfer.ron",
            r#"(state_file:"build/state.bincode",top_names:{"build/vcd.fst": "TOP::top_simulation"})"#,
        )
        .unwrap();

        let mut internal_bytes = vec![255u8; W * H * 4];
        let mut vcd = if args.dump_vcd {
            Some(top.open_trace("./build/vcd.fst"))
        } else {
            None
        };
        let mut timestamp = 0;
        let mut x = 0i64;
        let mut y = 0i64;
        let mut num_frames = 0;
        let mut ticks = 0;
        top.rstn = 1;

        loop {
            if should_exit.try_recv().is_ok() {
                break;
            }

            top.buttons = sim_buttons.load(Ordering::Relaxed);

            sim_leds.store(top.leds as u8, Ordering::Relaxed);

            if top.hsync == 1 {
                while top.hsync == 1 {
                    top.tick(&mut vcd, &mut timestamp);
                }
                x = -220;
                y += 1;
            }
            if top.vsync == 1 {
                while top.vsync == 1 {
                    top.tick(&mut vcd, &mut timestamp);
                }
                x = -220;
                y = -20;

                // println!("Vsync!");
                update_frame.send(internal_bytes).ok();
                internal_bytes = collect_frame.recv().unwrap();
                // texture.update_from_bytes(W as u32, H as u32, &bytes);
                // println!("Done copying!");
                num_frames += 1;

                if let Some(sim_num_frames) = sim_num_frames
                    && num_frames >= sim_num_frames
                    && sim_dump_vcd
                {
                    break;
                }
            }

            if x >= 0 && y >= 0 && x < W as i64 && y < H as i64 {
                internal_bytes[x as usize * 4 + y as usize * W * 4] = top.r;
                internal_bytes[1 + x as usize * 4 + y as usize * W * 4] = top.g;
                internal_bytes[2 + x as usize * 4 + y as usize * W * 4] = top.b;
            }
            // dbg!((x, y, top.r, top.g, top.b));

            top.tick(&mut vcd, &mut timestamp);
            x += 1;
            ticks += 1;
            if let Some(max) = sim_num_ticks {
                if ticks >= max {
                    break;
                }
            }
        }
        print!("Worker thread exited ");
    });

    clear_background(BLACK);
    next_frame().await;

    let mut last_keys_text = String::new();
    let mut last_key_time = 0.0;

    loop {
        if is_key_pressed(KeyCode::Q) {
            trigger_exit.send(()).ok();
            break Ok(());
        }

        let mut keys = 0xF;
        keys = (keys << 1) | !is_key_down(KeyCode::Space) as u8;
        keys = (keys << 1) | !is_key_down(KeyCode::T) as u8;
        buttons_state.store(keys, Ordering::Relaxed);

        if let Ok(new_frame) = receive_frame.try_recv() {
            return_frame.send(bytes).ok();
            texture.update_from_bytes(W as u32, H as u32, &new_frame);
            bytes = new_frame;
            // println!("Received new frame");
        }

        draw_texture_ex(
            &texture,
            0.0,
            0.0,
            WHITE,
            DrawTextureParams {
                dest_size: Some(Vec2::new(W as f32, H as f32)),
                ..Default::default()
            },
        );

        let pressed = get_keys_pressed();
        if !pressed.is_empty() {
            last_keys_text = pressed
                .iter()
                .map(|k| format!("{k:?}"))
                .collect::<Vec<_>>()
                .join(", ");
            last_key_time = get_time();
        }

        let elapsed = get_time() - last_key_time;
        if elapsed < 3.0 && !last_keys_text.is_empty() {
            let alpha = if elapsed < 2.0 { 1.0 } else { 3.0 - elapsed };
            let font_size = 30.;
            let padding = 12.0;
            let corner_radius = 8.0f32;
            let m = measure_text(&last_keys_text, None, font_size as u16, 1.0);

            let box_w = m.width + padding * 2.0;
            let box_h = m.height + padding * 2.0;
            let box_x = (W as f32 - box_w) / 2.0;
            let box_y = H as f32 - 40.0 - box_h;

            let bg = Color::new(0.0, 0.05, 0.2, (0.85 * alpha) as f32);
            let r = corner_radius.min(box_w / 2.0).min(box_h / 2.0);
            draw_rectangle(box_x + r, box_y, box_w - 2.0 * r, box_h, bg);
            draw_rectangle(box_x, box_y + r, box_w, box_h - 2.0 * r, bg);
            draw_circle(box_x + r, box_y + r, r, bg);
            draw_circle(box_x + box_w - r, box_y + r, r, bg);
            draw_circle(box_x + r, box_y + box_h - r, r, bg);
            draw_circle(box_x + box_w - r, box_y + box_h - r, r, bg);

            let text_x = box_x + padding;
            let text_y = box_y + (box_h) / 2.0;
            // let text_y = box_y + (box_h - m.height) / 2.0 - m.offset_y;
            draw_text(
                &last_keys_text,
                text_x,
                text_y,
                font_size,
                Color::new(1.0, 1.0, 1.0, alpha as f32),
            );
        }

        let led_val = leds_state.load(Ordering::Relaxed);
        let led_radius = 8.0;
        let led_spacing = 28.0;
        let start_x = W as f32 - 20.0;
        let start_y = H as f32 - 30.0;
        for i in 0..8 {
            let x = start_x - i as f32 * led_spacing;
            let y = start_y;
            let on = (led_val >> i) & 1 == 1;
            let color = if on {
                GREEN
            } else {
                Color::new(0.15, 0.15, 0.15, 1.0)
            };
            draw_circle(x, y, led_radius, color);
            if on {
                draw_circle(x, y, led_radius * 0.5, Color::new(0.6, 1.0, 0.6, 0.6));
            }
        }

        next_frame().await;
        sleep(Duration::from_millis(10));
    }
}
