#!/usr/bin/env python3
"""
Diffusion Pipe Helper - Interactive Training Script
A Python version of the original bash interactive training script with Rich UI
"""

import subprocess
import os
import sys
import time
import shutil
from pathlib import Path

try:
    from rich.console import Console
    from rich.table import Table
    from rich.prompt import Prompt, Confirm
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
except ImportError:
    print("Error: Rich library not installed. Run: pip install rich")
    sys.exit(1)

console = Console()

# Configuration
NETWORK_VOLUME = os.environ.get('NETWORK_VOLUME', '/workspace')
WORKING_DIR = f"{NETWORK_VOLUME}/diffusion-pipe-working-folder"

# Model definitions
MODELS = {
    'flux': {
        'name': 'Flux',
        'type': 'Image',
        'hf_repo': 'black-forest-labs/FLUX.1-dev',
        'local_dir': f'{NETWORK_VOLUME}/models/flux',
        'toml': 'flux.toml',
        'training_script': 'start_flux_training.sh',
        'requires_token': True,
        'model_file': 'flux1-dev.safetensors'
    },
    'sdxl': {
        'name': 'SDXL',
        'type': 'Image',
        'hf_repo': 'timoshishi/sdXL_v10VAEFix',
        'hf_files': ['sdXL_v10VAEFix.safetensors'],
        'local_dir': f'{NETWORK_VOLUME}/models',
        'toml': 'sdxl.toml',
        'training_script': 'start_sdxl_training.sh',
        'requires_token': False,
        'model_file': 'sdXL_v10VAEFix.safetensors'
    },
    'wan13': {
        'name': 'Wan 1.3B',
        'type': 'Video',
        'hf_repo': 'Wan-AI/Wan2.1-T2V-1.3B',
        'local_dir': f'{NETWORK_VOLUME}/models/Wan/Wan2.1-T2V-1.3B',
        'toml': 'wan13_video.toml',
        'training_script': 'start_wan_t2v_13b_training.sh',
        'requires_token': False,
        'model_file': 'diffusion_pytorch_model.safetensors'
    },
    'wan14b_t2v': {
        'name': 'Wan 14B Text-To-Video',
        'type': 'Video',
        'hf_repo': 'Wan-AI/Wan2.1-T2V-14B',
        'local_dir': f'{NETWORK_VOLUME}/models/Wan/Wan2.1-T2V-14B',
        'toml': 'wan14b_t2v.toml',
        'training_script': 'start_wan_t2v_14b_training.sh',
        'requires_token': False,
        'model_file': 'diffusion_pytorch_model.safetensors'
    },
    'wan14b_i2v': {
        'name': 'Wan 14B Image-To-Video',
        'type': 'Video',
        'hf_repo': 'Wan-AI/Wan2.1-I2V-14B-480P',
        'local_dir': f'{NETWORK_VOLUME}/models/Wan/Wan2.1-I2V-14B-480P',
        'toml': 'wan14b_i2v.toml',
        'training_script': 'start_wan_i2v_480p_training.sh',
        'requires_token': False,
        'model_file': 'diffusion_pytorch_model.safetensors'
    },
    'qwen': {
        'name': 'Qwen Image',
        'type': 'Image',
        'hf_repo': 'Qwen/Qwen-Image',
        'local_dir': f'{NETWORK_VOLUME}/models/Qwen-Image',
        'toml': 'qwen_toml.toml',
        'training_script': None,  # Inline training
        'requires_token': False,
        'model_file': 'model.safetensors'
    },
    'z_image_turbo': {
        'name': 'Z Image Turbo',
        'type': 'Image',
        'hf_repo': 'Comfy-Org/z_image_turbo',
        'local_dir': f'{NETWORK_VOLUME}/models/z_image',
        'toml': 'z_image_toml.toml',
        'training_script': None,  # Inline training
        'requires_token': False,
        'special_download': True  # Complex multi-file download
    }
}


def show_welcome():
    """Show welcome banner"""
    console.clear()
    console.print(Panel.fit(
        "[bold cyan]Diffusion Pipe Helper - Interactive Training[/bold cyan]\n"
        "[dim]A Python version with Rich UI[/dim]",
        border_style="cyan"
    ))
    console.print()


def show_menu():
    """Show model selection menu"""
    table = Table(title="Select Model to Train", show_header=True, header_style="bold cyan")
    table.add_column("#", style="cyan", width=3)
    table.add_column("Model", style="green", width=30)
    table.add_column("Type", style="yellow", width=10)
    
    table.add_row("1", "Flux", "Image")
    table.add_row("2", "SDXL", "Image")
    table.add_row("3", "Wan 1.3B", "Video")
    table.add_row("4", "Wan 14B Text-To-Video", "Video")
    table.add_row("5", "Wan 14B Image-To-Video", "Video")
    table.add_row("6", "Qwen Image", "Image")
    table.add_row("7", "Z Image Turbo", "Image")
    
    console.print(table)
    console.print()
    
    choice = Prompt.ask(
        "Enter your choice",
        choices=["1", "2", "3", "4", "5", "6", "7"],
        default="1"
    )
    
    model_map = {
        "1": "flux",
        "2": "sdxl",
        "3": "wan13",
        "4": "wan14b_t2v",
        "5": "wan14b_i2v",
        "6": "qwen",
        "7": "z_image_turbo"
    }
    
    return model_map[choice]


def get_api_token(model_key):
    """Get API token if required"""
    model = MODELS[model_key]
    
    if not model['requires_token']:
        return None
    
    # Check if already set
    token = os.environ.get('HUGGING_FACE_TOKEN')
    if token and token != 'token_here':
        console.print("[green]Hugging Face token already set[/green]")
        return token
    
    console.print()
    console.print("[yellow]Hugging Face token required for this model[/yellow]")
    console.print("[dim]Get your token from: https://huggingface.co/settings/tokens[/dim]")
    console.print()
    
    token = Prompt.ask("Enter your Hugging Face token", password=True)
    
    if not token:
        console.print("[red]Token cannot be empty. Exiting.[/red]")
        sys.exit(1)
    
    os.environ['HUGGING_FACE_TOKEN'] = token
    console.print("[green]Token set successfully[/green]")
    return token


def get_caption_mode():
    """Ask user about captioning"""
    console.print()
    console.print(Panel(
        "[bold]Dataset Captioning[/bold]\n\n"
        "Do you want to auto-caption your dataset?",
        border_style="cyan"
    ))
    console.print()
    
    table = Table(show_header=False)
    table.add_column("Option", style="cyan")
    table.add_column("Description", style="white")
    
    table.add_row("1", "Caption images only")
    table.add_row("2", "Caption videos only")
    table.add_row("3", "Caption both images and videos")
    table.add_row("4", "Skip captioning")
    
    console.print(table)
    console.print()
    
    choice = Prompt.ask(
        "Enter your choice",
        choices=["1", "2", "3", "4"],
        default="4"
    )
    
    mode_map = {
        "1": "images",
        "2": "videos",
        "3": "both",
        "4": "skip"
    }
    
    return mode_map[choice]


def validate_dataset(caption_mode):
    """Validate dataset folders"""
    console.print()
    console.print(Panel("[bold cyan]Dataset Validation[/bold cyan]", border_style="cyan"))
    console.print()
    
    image_dir = f"{NETWORK_VOLUME}/image_dataset_here"
    video_dir = f"{NETWORK_VOLUME}/video_dataset_here"
    
    issues = []
    
    # Check image dataset
    if caption_mode in ['images', 'both']:
        if not os.path.exists(image_dir):
            issues.append(f"Image dataset folder not found: {image_dir}")
        else:
            image_files = [f for f in os.listdir(image_dir) 
                          if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            if len(image_files) == 0:
                issues.append(f"No images found in: {image_dir}")
            else:
                console.print(f"[green]✓ Found {len(image_files)} images[/green]")
    
    # Check video dataset
    if caption_mode in ['videos', 'both']:
        if not os.path.exists(video_dir):
            issues.append(f"Video dataset folder not found: {video_dir}")
        else:
            video_files = [f for f in os.listdir(video_dir) 
                          if f.lower().endswith(('.mp4', '.avi', '.mov'))]
            if len(video_files) == 0:
                issues.append(f"No videos found in: {video_dir}")
            else:
                console.print(f"[green]✓ Found {len(video_files)} videos[/green]")
    
    if issues:
        console.print()
        for issue in issues:
            console.print(f"[yellow]⚠ {issue}[/yellow]")
        console.print()
        if not Confirm.ask("Continue anyway?", default=False):
            sys.exit(0)
    
    console.print()
    return True


def download_model(model_key, token=None):
    """Download model from HuggingFace"""
    model = MODELS[model_key]
    
    console.print()
    console.print(Panel(
        f"[bold cyan]Downloading {model['name']}[/bold cyan]\n"
        f"[dim]From: {model['hf_repo']}[/dim]\n"
        f"[dim]To: {model['local_dir']}[/dim]",
        border_style="cyan"
    ))
    console.print()
    
    # Create directory
    os.makedirs(model['local_dir'], exist_ok=True)
    
    # Check if already downloaded
    if model.get('model_file'):
        model_path = os.path.join(model['local_dir'], model['model_file'])
        if os.path.exists(model_path):
            console.print(f"[yellow]Model already exists at: {model_path}[/yellow]")
            if Confirm.ask("Skip download?", default=True):
                console.print("[green]✓ Using existing model[/green]")
                return True
    
    # Build download command
    cmd = ['huggingface-cli', 'download', model['hf_repo'], '--local-dir', model['local_dir']]
    
    if model.get('hf_files'):
        for file in model['hf_files']:
            cmd.append(file)
    
    if token:
        cmd.extend(['--token', token])
    
    # Start download in background
    log_file = f"{NETWORK_VOLUME}/logs/model_download.log"
    console.print(f"[cyan]Starting download in background...[/cyan]")
    console.print(f"[dim]To monitor: tail -f {log_file}[/dim]")
    console.print()
    
    with open(log_file, 'w') as f:
        process = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
    
    # Wait for download with timeout
    timeout = 10800  # 3 hours
    elapsed = 0
    
    with Progress(
        SpinnerColumn(),
        TextColumn("[cyan]{task.description}[/cyan]"),
        BarColumn(),
        console=console
    ) as progress:
        task = progress.add_task("Downloading...", total=None)
        
        while process.poll() is None:
            time.sleep(3)
            elapsed += 3
            progress.update(task, advance=1)
            
            if elapsed >= timeout:
                console.print("[red]Download timed out after 3 hours![/red]")
                process.kill()
                return False
    
    if process.returncode != 0:
        console.print(f"[red]Download failed with exit code {process.returncode}[/red]")
        console.print(f"[yellow]Check log: {log_file}[/yellow]")
        return False
    
    console.print("[green]✓ Download complete![/green]")
    return True


def launch_training(model_key):
    """Launch training for selected model"""
    model = MODELS[model_key]
    
    console.print()
    console.print(Panel(
        f"[bold green]Starting Training: {model['name']}[/bold green]\n"
        f"[dim]Configuration: {model['toml']}[/dim]",
        border_style="green"
    ))
    console.print()
    
    # Change to diffusion_pipe directory
    diffusion_pipe_dir = f"{WORKING_DIR}/diffusion_pipe"
    
    if not os.path.exists(diffusion_pipe_dir):
        console.print(f"[red]Error: {diffusion_pipe_dir} not found![/red]")
        console.print("[yellow]Run setup.sh first![/yellow]")
        sys.exit(1)
    
    os.chdir(diffusion_pipe_dir)
    
    # Upgrade dependencies
    console.print("[cyan]Upgrading dependencies...[/cyan]")
    subprocess.run(['pip', 'install', 'transformers', '-U', '-q'])
    subprocess.run(['pip', 'install', '--upgrade', 'peft>=0.17.0', '-q'])
    console.print("[green]✓ Dependencies updated[/green]")
    console.print()
    
    # Special warnings for certain models
    if model_key in ['qwen', 'z_image_turbo']:
        console.print(Panel(
            "[yellow]⚠ IMPORTANT: Model initialization can take several minutes.[/yellow]\n"
            "[yellow]⚠ The script may appear to hang - this is NORMAL.[/yellow]\n"
            "[yellow]⚠ As long as it doesn't exit with error, let it run.[/yellow]",
            border_style="yellow"
        ))
        console.print()
        console.print("[cyan]Waiting 10 seconds...[/cyan]")
        time.sleep(10)
        console.print()
    
    console.print("[bold green]Training is starting...[/bold green]")
    console.print()
    
    # Prepare environment
    env = os.environ.copy()
    env['NCCL_P2P_DISABLE'] = '1'
    env['NCCL_IB_DISABLE'] = '1'
    
    # Check if model has separate training script
    if model['training_script']:
        # Call separate bash script
        script_path = f"{WORKING_DIR}/training_scripts/{model['training_script']}"
        if os.path.exists(script_path):
            subprocess.run(['bash', script_path], env=env)
        else:
            console.print(f"[red]Training script not found: {script_path}[/red]")
            sys.exit(1)
    else:
        # Run training inline
        subprocess.run([
            'deepspeed', '--num_gpus=1',
            'train.py', '--deepspeed',
            '--config', f'examples/{model["toml"]}'
        ], env=env)
    
    console.print()
    console.print("[bold green]✓ Training completed![/bold green]")


def main():
    """Main orchestration"""
    try:
        # Show welcome
        show_welcome()
        
        # Show menu and get selection
        model_key = show_menu()
        model = MODELS[model_key]
        
        console.print()
        console.print(f"[green]✓ Selected: {model['name']}[/green]")
        
        # Get API token if needed
        token = get_api_token(model_key)
        
        # Get caption mode
        caption_mode = get_caption_mode()
        
        # Validate dataset
        validate_dataset(caption_mode)
        
        # Show configuration summary
        console.print(Panel(
            f"[bold]Configuration Summary[/bold]\n\n"
            f"Model: {model['name']}\n"
            f"Type: {model['type']}\n"
            f"Caption Mode: {caption_mode}\n"
            f"Config: {model['toml']}",
            border_style="cyan"
        ))
        console.print()
        
        if not Confirm.ask("Start training with this configuration?", default=True):
            console.print("[yellow]Cancelled by user[/yellow]")
            sys.exit(0)
        
        # Download model
        if not download_model(model_key, token):
            console.print("[red]Download failed, cannot continue[/red]")
            sys.exit(1)
        
        # Launch training
        launch_training(model_key)
        
    except KeyboardInterrupt:
        console.print()
        console.print("[yellow]Cancelled by user[/yellow]")
        sys.exit(0)
    except Exception as e:
        console.print()
        console.print(f"[red]Error: {str(e)}[/red]")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
