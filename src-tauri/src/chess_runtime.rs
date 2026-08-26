use my_lisp::{parse, eval_expr, Session, Value};
use serde::Serialize;
use std::sync::mpsc::{channel, Sender};
use std::thread;

/// Typed request sent from Tauri command to the worker thread.
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub enum RuntimeRequest {
    Eval { source: String },
    Load { path: String },
}

/// Typed response sent back from the worker thread.
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
                    let source = match std::fs::read_to_string(path) {
                        Ok(s) => s,
                        Err(_) => continue,
                    };
                    match parse(&source) {
                        Ok(exprs) => {
                            for expr in exprs {
                                let _ = eval_expr(&expr, &session.environment);
                            }
                        }
                        Err(_) => continue,
                    }
                    break;
                }
            }

            // Event loop: process requests sequentially.
            while let Ok(request) = receiver.recv() {
                match request {
                    RuntimeRequest::Eval { source } => {
                        let response = match parse(&source) {
                            Ok(exprs) => {
                                let mut last = Value::Nil;
                                for expr in exprs {
                                    match eval_expr(&expr, &session.environment) {
                                        Ok(value) => last = value,
                                        Err(error) => {
                                            let _ = Self::respond_ok(&RuntimeResponse::Err {
                                                message: error.to_string(),
                                            });
                                            break;
                                        }
                                    }
                                }
                                RuntimeResponse::Ok {
                                    value: last.to_string(),
                                }
                            }
                            Err(error) => RuntimeResponse::Err {
                                message: error.to_string(),
                            },
                        };
                        let _ = Self::respond_ok(&response);
                    }
                    RuntimeRequest::Load { path } => {
                        let response = match std::fs::read_to_string(&path) {
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
                        };
                        let _ = Self::respond_ok(&response);
                    }
                }
            }
        });

        Self { sender }
    }

    /// Send a request to the worker. For MVP, responses are fire-and-forget
    /// through a side channel; full bidirectional sync can be added later.
    pub fn send(&self, request: RuntimeRequest) -> Result<(), String> {
        self.sender
            .send(request)
            .map_err(|e| format!("runtime disconnected: {}", e))
    }

    fn respond_ok(_response: &RuntimeResponse) -> Result<(), ()> {
        // Placeholder: in full implementation, this sends back through
        // a response channel. For MVP, we fire-and-forget.
        Ok(())
    }
}

/// Synchronous evaluation helper for Tauri commands.
/// Creates a one-shot channel, sends Eval request, waits for response.
pub fn eval_sync(source: String) -> Result<String, String> {
    // For MVP: simple direct evaluation without persistent session.
    // Full actor with response channel comes next iteration.
    my_lisp_host::install();
    let session = Session::default();
    let expressions = parse(&source).map_err(|e| e.to_string())?;
    let mut last = Value::Nil;
    for expr in expressions {
        last = eval_expr(&expr, &session.environment).map_err(|e| e.to_string())?;
    }
    Ok(last.to_string())
}
