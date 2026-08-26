mod chess_runtime;

use chess_runtime::{eval_sync, ChessRuntime, RequestKind, RuntimeResponse};
use std::sync::Mutex;
use tauri::State;

/// Application state: single-owner my-lisp runtime actor.
struct AppState {
    runtime: Mutex<ChessRuntime>,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(AppState {
            runtime: Mutex::new(ChessRuntime::new()),
        })
        .invoke_handler(tauri::generate_handler![
            greet,
            eval_my_lisp,
            load_my_lisp_file,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! Welcome to chess-lisp-zero.", name)
}

/// Evaluate my-lisp source code through the embedded runtime.
/// Returns the string representation of the last evaluated value.
#[tauri::command]
fn eval_my_lisp(source: String) -> Result<String, String> {
    eval_sync(source)
}

/// Load and evaluate a my-lisp file through the embedded runtime.
#[tauri::command]
fn load_my_lisp_file(path: String, state: State<AppState>) -> Result<String, String> {
    let runtime = state.runtime.lock().map_err(|e| e.to_string())?;
    match runtime.request(RequestKind::Load { path })? {
        RuntimeResponse::Ok { value } => Ok(value),
        RuntimeResponse::Err { message } => Err(message),
    }
}
