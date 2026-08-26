use my_lisp::{parse, eval_expr, Session, Value};
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

/// Single-owner my-lisp runtime actor.
///
/// One worker thread creates and owns the Session, preloads core.my,
/// and accepts typed channel requests. No unsafe shared Session —
/// all access is sequential through the worker's channel.
pub struct ChessRuntime {
    sender: Sender<RuntimeRequest>,
}

impl ChessRuntime {
    /// Spawn the worker thread and return the handle.
    pub fn new() -> Self {
        let (sender, receiver) = channel::<RuntimeRequest>();

        thread::spawn(move || {
            // Install host capabilities (filesystem, TCP, process-run).
            my_lisp_host::install();

            // Create session with root environment.
            let session = Session::default();

            // Try to preload core.my from sibling my-lisp repo.
            let core_paths = [
                "../my-lisp/lib/core.my",
                "../../my-lisp/lib/core.my",
                "../../../my-lisp/lib/core.my",
            ];
            for path in &core_paths {
                if std::path::Path::new(path).exists() {
                    if let Ok(source) = std::fs::read_to_string(path) {
                        if let Ok(exprs) = parse(&source) {
                            for expr in exprs {
                                let _ = eval_expr(&expr, &session.environment);
                            }
                            break;
                        }
                    }
                }
            }

            // Event loop: process requests sequentially.
            while let Ok(request) = receiver.recv() {
                let response = match request.kind {
                    RequestKind::Eval { source } => {
                        match parse(&source) {
                            Ok(exprs) => {
                                let mut last = Value::Nil;
                                let mut error = None;
                                for expr in exprs {
                                    match eval_expr(&expr, &session.environment) {
                                        Ok(value) => last = value,
                                        Err(err) => {
                                            error = Some(err.to_string());
                                            break;
                                        }
                                    }
                                }
                                if let Some(msg) = error {
                                    RuntimeResponse::Err { message: msg }
                                } else {
                                    RuntimeResponse::Ok { value: last.to_string() }
                                }
                            }
                            Err(error) => RuntimeResponse::Err {
                                message: error.to_string(),
                            },
                        }
                    }
                    RequestKind::Load { path } => {
                        match std::fs::read_to_string(&path) {
                            Ok(source) => match parse(&source) {
                                Ok(exprs) => {
                                    for expr in exprs {
                                        let _ = eval_expr(&expr, &session.environment);
                                    }
                                    RuntimeResponse::Ok {
                                        value: format!("loaded {}", path),
                                    }
                                }
                                Err(error) => RuntimeResponse::Err {
                                    message: error.to_string(),
                                },
                            },
                            Err(error) => RuntimeResponse::Err {
                                message: format!("read error: {}", error),
                            },
                        }
                    }
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
