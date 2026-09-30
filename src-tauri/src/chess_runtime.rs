use sens::{eval_program, load_core_library, Environment, Session};
use serde::Serialize;
use std::sync::mpsc::{channel, Sender};
use std::thread;

/// Typed request with a response channel attached.
pub struct RuntimeRequest {
    pub kind: RequestKind,
    /// Response channel: worker sends RuntimeResponse here.
    pub respond_to: Sender<RuntimeResponse>,
}

#[derive(Debug, Clone)]
pub enum RequestKind {
    Eval { source: String },
    Load { path: String },
}

/// Typed response from the worker thread.
#[derive(Debug, Clone, Serialize)]
pub enum RuntimeResponse {
    Ok { value: String },
    Err { message: String },
}

/// Single-owner SENS runtime actor.
///
/// One worker thread creates and owns the Session, bootstraps the embedded
/// canonical Core4 library, and accepts typed channel requests. No unsafe
/// shared Session — all access is sequential through the worker's channel.
pub struct ChessRuntime {
    sender: Sender<RuntimeRequest>,
}

impl ChessRuntime {
    /// Spawn the worker thread and return the handle.
    pub fn new() -> Self {
        let (sender, receiver) = channel::<RuntimeRequest>();

        thread::spawn(move || {
            // Install host capabilities (filesystem, TCP, process-run).
            sens_host::install();

            // One mutable session owns all lowering/evaluation state. Core4 is
            // embedded by the sens crate; no sibling-repository source path.
            let mut session = Session {
                environment: Environment::root(),
            };
            load_core_library(&mut session)
                .expect("embedded SENS Core4 library must bootstrap");

            // Event loop: process requests sequentially.
            while let Ok(request) = receiver.recv() {
                let response = match request.kind {
                    RequestKind::Eval { source } => match eval_program(&source, &mut session) {
                        Ok(result) => RuntimeResponse::Ok {
                            value: result.value.to_string(),
                        },
                        Err(error) => RuntimeResponse::Err {
                            message: error.to_string(),
                        },
                    },
                    RequestKind::Load { path } => match std::fs::read_to_string(&path) {
                        Ok(source) => match eval_program(&source, &mut session) {
                            Ok(_) => RuntimeResponse::Ok {
                                value: format!("loaded {}", path),
                            },
                            Err(error) => RuntimeResponse::Err {
                                message: error.to_string(),
                            },
                        },
                        Err(error) => RuntimeResponse::Err {
                            message: format!("read error: {}", error),
                        },
                    },
                };
                // Send response back; ignore send failure (caller dropped).
                let _ = request.respond_to.send(response);
            }
        });

        Self { sender }
    }

    /// Send a request and wait for the response synchronously.
    pub fn request(&self, kind: RequestKind) -> Result<RuntimeResponse, String> {
        let (respond_to, rx) = channel::<RuntimeResponse>();
        self.sender
            .send(RuntimeRequest { kind, respond_to })
            .map_err(|e| format!("runtime disconnected: {}", e))?;
        rx.recv()
            .map_err(|e| format!("runtime response channel closed: {}", e))
    }
}

/// Synchronous evaluation helper for Tauri commands.
/// Creates a one-shot request through the actor.
pub fn eval_sync(source: String) -> Result<String, String> {
    let runtime = ChessRuntime::new();
    match runtime.request(RequestKind::Eval { source })? {
        RuntimeResponse::Ok { value } => Ok(value),
        RuntimeResponse::Err { message } => Err(message),
    }
}
