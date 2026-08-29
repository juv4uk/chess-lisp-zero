#!/usr/bin/env python3
"""
PyTorch Teacher Oracle for chess-lisp-zero.
Defines a process boundary that evaluates the existing chess-tauri-zero
policy/value network. It takes a FEN string and outputs the deterministic
policy and value as JSON, satisfying CHESS-LISP-ZERO-PYTORCH-TEACHER-ORACLE.
"""
import sys
import os
import json
import argparse

# Add chess-tauri-zero to PYTHONPATH
TAURI_ZERO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../chess-tauri-zero"))
sys.path.insert(0, os.path.join(TAURI_ZERO_DIR, "src"))

import torch
from chess_zero.agent.torch_model import ChessResNet
from chess_zero.agent.load_weights import load_torch_model
from chess_zero.env.chess_env import canon_input_planes
from chess_zero.config import create_uci_labels

def main():
    parser = argparse.ArgumentParser(description="PyTorch Teacher Oracle")
    parser.add_argument("--fen", type=str, required=True, help="FEN string to evaluate")
    parser.add_argument("--model-path", type=str, 
                        default=os.path.join(TAURI_ZERO_DIR, "data/model/model_best_weight.h5"),
                        help="Path to the h5 weights file")
    args = parser.parse_args()

    if not os.path.exists(args.model_path):
        print(json.dumps({"error": f"Model not found: {args.model_path}"}))
        sys.exit(1)

    labels = create_uci_labels()
    model = load_torch_model(args.model_path, filters=256, res_blocks=7, n_labels=len(labels))
    model.eval()
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)

    # Convert FEN to 18x8x8 canonical planes
    planes = canon_input_planes(args.fen)
    
    # Input is (batch, channels, height, width) = (1, 18, 8, 8)
    tensor = torch.from_numpy(planes).unsqueeze(0).to(device)

    with torch.no_grad():
        policy_logits, value_out = model(tensor)
        policy_probs = torch.softmax(policy_logits, dim=1).squeeze(0).cpu().numpy().tolist()
        value = value_out.squeeze().item()

    # Map probabilities to UCI labels for non-zero or top N
    # For determinism and compactness, just output the top 10 moves or all
    # Let's output all non-zero (or just the array)
    
    output = {
        "fen": args.fen,
        "value": value,
        "policy": {labels[i]: p for i, p in enumerate(policy_probs) if p > 1e-4},
        "provenance": {
            "model_path": args.model_path,
            "architecture": "ChessResNet(filters=256, res_blocks=7)",
            "device": str(device)
        }
    }
    print(json.dumps(output, indent=2))

if __name__ == "__main__":
    main()
