#!/usr/bin/env bash

# Determine which branch to clone based on environment variables
BRANCH="main"  # Default branch

if [ "$is_dev" == "true" ]; then
    BRANCH="dev"
    echo "Development mode enabled. Cloning dev branch..."
elif [ -n "$git_branch" ]; then
    BRANCH="$git_branch"
    echo "Custom branch specified: $git_branch"
else
    echo "Using default branch: main"
fi

# Clone the repository to a temporary location with the specified branch
echo "Cloning branch '$BRANCH' from repository..."
git clone --branch "$BRANCH" https://github.com/antique3e/diffusion-pipe-helper.git /tmp/diffusion-pipe-helper

# Check if clone was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to clone branch '$BRANCH'. Falling back to main branch..."
    git clone https://github.com/antique3e/diffusion-pipe-helper.git /tmp/diffusion-pipe-helper

    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone repository. Exiting..."
        exit 1
    fi
fi

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Check if workspace exists and set network volume accordingly
if [ ! -d "/workspace" ]; then
    echo "NETWORK_VOLUME directory '/workspace' does not exist. You are NOT using a network volume. Setting NETWORK_VOLUME to '/diffusion-pipe-working-folder' (root directory)."
    mkdir -p "/diffusion-pipe-working-folder"
    NETWORK_VOLUME="/diffusion-pipe-working-folder"
else
    echo "Network volume detected at /workspace. Using /workspace/diffusion-pipe-working-folder as working directory."
    mkdir -p "/workspace/diffusion-pipe-working-folder"
    NETWORK_VOLUME="/workspace/diffusion-pipe-working-folder"
fi
export NETWORK_VOLUME

echo "cd $NETWORK_VOLUME" >> /root/.bashrc

# GPU detection for optimized flash-attn build
detect_cuda_arch() {
    local gpu_name
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 | xargs)
    
    # Save GPU name for other scripts to check
    echo "$gpu_name" > /tmp/detected_gpu
    
    case "$gpu_name" in
        # Blackwell Data Center (sm_100)
        *B100*|*B200*|*GB200*)
            echo "blackwell" > /tmp/gpu_arch_type
            echo "100"
            ;;
        # Blackwell Consumer/Pro (sm_120)
        *5090*|*5080*|*5070*|*5060*|*PRO*6000*Blackwell*)
            echo "blackwell" > /tmp/gpu_arch_type
            echo "120"
            ;;
        # Hopper (sm_90)
        *H100*|*H200*)
            echo "hopper" > /tmp/gpu_arch_type
            echo "90"
            ;;
        # Ada Lovelace (sm_89)
        *L4*|*L40*|*4090*|*4080*|*4070*|*4060*|*PRO*6000*Ada*)
            echo "ada" > /tmp/gpu_arch_type
            echo "89"
            ;;
        # Ampere (sm_86)
        *A10*|*A40*|*A6000*|*A5000*|*A4000*|*3090*|*3080*|*3070*|*3060*)
            echo "ampere" > /tmp/gpu_arch_type
            echo "86"
            ;;
        # Ampere Data Center (sm_80)
        *A100*)
            echo "ampere" > /tmp/gpu_arch_type
            echo "80"
            ;;
        # Turing (sm_75)
        *T4*|*2080*|*2070*|*2060*)
            echo "turing" > /tmp/gpu_arch_type
            echo "75"
            ;;
        # Volta (sm_70)
        *V100*)
            echo "volta" > /tmp/gpu_arch_type
            echo "70"
            ;;
        # Default: build for common modern architectures
        *)
            echo "unknown" > /tmp/gpu_arch_type
            echo "80;86;89;90"
            ;;
    esac
}

# Install flash-attn
echo "Installing flash-attn..."
mkdir -p "$NETWORK_VOLUME/logs"

# Detect GPU and set optimal CUDA architecture
DETECTED_GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 | xargs)
CUDA_ARCH=$(detect_cuda_arch)
echo "Detected GPU: $DETECTED_GPU"
echo "Using CUDA architecture: $CUDA_ARCH"

# Specify the exact prebuilt wheel URL here
FLASH_ATTN_WHEEL_URL="https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.5.4/flash_attn-2.8.3+cu128torch2.9-cp312-cp312-linux_x86_64.whl"

WHEEL_INSTALLED=false

# Try prebuilt wheel if URL is provided (in foreground)
if [ -n "$FLASH_ATTN_WHEEL_URL" ]; then
    echo "Attempting to download prebuilt flash-attn wheel..."
    echo "  URL: $FLASH_ATTN_WHEEL_URL"
    
    cd /tmp
    WHEEL_NAME=$(basename "$FLASH_ATTN_WHEEL_URL")
    
    if wget -q -O "$WHEEL_NAME" "$FLASH_ATTN_WHEEL_URL" 2>&1; then
        echo "  Wheel downloaded successfully!"
        echo "  Installing wheel..."
        if pip install "$WHEEL_NAME" 2>&1; then
            rm -f "$WHEEL_NAME"
            echo "✅ Successfully installed flash-attn from prebuilt wheel!"
            WHEEL_INSTALLED=true
            touch /tmp/flash_attn_wheel_success
        else
            echo "  Wheel installation failed, will build from source."
            rm -f "$WHEEL_NAME"
        fi
    else
        echo "  Failed to download wheel, will build from source."
    fi
else
    echo "No prebuilt wheel URL specified (FLASH_ATTN_WHEEL_URL is empty)."
    echo "Will build flash-attn from source."
fi

# Fall back to building from source in background if wheel not installed
if [ "$WHEEL_INSTALLED" = false ]; then
    echo ""
    echo "⚠️  Starting flash-attn build from source in background..."
    echo "   This may take 3-10 minutes depending on your system."
    echo ""
    
    # Dynamically calculate MAX_JOBS for fallback build
    CPU_CORES=$(nproc)
    CPU_JOBS=$(( CPU_CORES - 2 ))
    [ "$CPU_JOBS" -lt 4 ] && CPU_JOBS=4
    AVAILABLE_RAM_GB=$(free -g | awk '/^Mem:/{print $7}')
    RAM_JOBS=$(( AVAILABLE_RAM_GB / 3 ))
    [ "$RAM_JOBS" -lt 4 ] && RAM_JOBS=4
    if [ "$CPU_JOBS" -lt "$RAM_JOBS" ]; then
        OPTIMAL_JOBS=$CPU_JOBS
    else
        OPTIMAL_JOBS=$RAM_JOBS
    fi
    
    # Build from source in background
    (
        set -e
        
        DETECTED_GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 | xargs)
        CUDA_ARCH=$(detect_cuda_arch)
        
        echo "Build configuration:"
        echo "  GPU: $DETECTED_GPU"
        echo "  CUDA Architecture: sm_$CUDA_ARCH"
        
        pip install ninja packaging -q
        if ! ninja --version > /dev/null 2>&1; then
            pip uninstall -y ninja && pip install ninja
        fi
        
        cd /tmp
        rm -rf flash-attention
        
        echo "Cloning flash-attention repository..."
        git clone https://github.com/Dao-AILab/flash-attention.git
        cd flash-attention
        
        export FLASH_ATTN_CUDA_ARCHS="$CUDA_ARCH"
        export MAX_JOBS=$OPTIMAL_JOBS
        export NVCC_THREADS=4
        
        echo "Building with optimizations:"
        echo "  FLASH_ATTN_CUDA_ARCHS=$FLASH_ATTN_CUDA_ARCHS"
        echo "  MAX_JOBS=$MAX_JOBS"
        echo "  NVCC_THREADS=$NVCC_THREADS"
        
        python setup.py install
        
        cd /tmp
        rm -rf flash-attention
        
        echo "✅ Successfully built and installed flash-attn from source!"
        
    ) > "$NETWORK_VOLUME/logs/flash_attn_install.log" 2>&1 &
    FLASH_ATTN_PID=$!
    echo "$FLASH_ATTN_PID" > /tmp/flash_attn_pid
    echo "flash-attn build started in background (PID: $FLASH_ATTN_PID)"
    echo "To monitor progress: tail -f $NETWORK_VOLUME/logs/flash_attn_install.log"
fi

# Start Jupyter Lab with the working folder as the root directory
jupyter-lab --ip=0.0.0.0 --allow-root --no-browser \
    --NotebookApp.token='' --NotebookApp.password='' \
    --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True \
    --notebook-dir="$NETWORK_VOLUME" &

# Copy helper files to working directory from cloned repository
if [ -d "/tmp/diffusion-pipe-helper" ]; then
    echo "Moving helper files from repository to working directory..."
    
    # Move the entire repository to working directory
    mv /tmp/diffusion-pipe-helper "$NETWORK_VOLUME/"
    
    # Move folders to root of working directory
    mv "$NETWORK_VOLUME/diffusion-pipe-helper/Captioning" "$NETWORK_VOLUME/"
    mv "$NETWORK_VOLUME/diffusion-pipe-helper/wan2.2_lora_training" "$NETWORK_VOLUME/"
    
    # Only move Qwen folder if IS_DEV is set to true
    if [ "$IS_DEV" == "true" ]; then
        mv "$NETWORK_VOLUME/diffusion-pipe-helper/qwen_image_musubi_training" "$NETWORK_VOLUME/" 2>/dev/null || true
    fi
    
    # Move src folder
    # if [ -d "$NETWORK_VOLUME/diffusion-pipe-helper/src" ]; then
    #     mv "$NETWORK_VOLUME/diffusion-pipe-helper/src" "$NETWORK_VOLUME/"
    # fi
    
    # Set up send_lora.sh script
    if [ -f "$NETWORK_VOLUME/src/send_lora.sh" ]; then
        chmod +x "$NETWORK_VOLUME/src/send_lora.sh"
        cp "$NETWORK_VOLUME/src/send_lora.sh" /usr/local/bin/
    fi
    
    # Move training scripts and utilities
    if [ -f "$NETWORK_VOLUME/diffusion-pipe-helper/interactive_start_training.py" ]; then
        mv "$NETWORK_VOLUME/diffusion-pipe-helper/interactive_start_training.py" "$NETWORK_VOLUME/"
        chmod +x "$NETWORK_VOLUME/interactive_start_training.py"
    fi
    
    if [ -f "$NETWORK_VOLUME/diffusion-pipe-helper/start_training.sh" ]; then
        mv "$NETWORK_VOLUME/diffusion-pipe-helper/start_training.sh" "$NETWORK_VOLUME/"
        chmod +x "$NETWORK_VOLUME/start_training.sh"
    fi
    
    if [ -f "$NETWORK_VOLUME/diffusion-pipe-helper/HowToUse.txt" ]; then
        mv "$NETWORK_VOLUME/diffusion-pipe-helper/HowToUse.txt" "$NETWORK_VOLUME/"
    fi
    
    # Move toml_files folder (no path updates - already hardcoded)
    # if [ -d "$NETWORK_VOLUME/diffusion-pipe-helper/toml_files" ]; then
    #     echo "Moving TOML files..."
    #     mv "$NETWORK_VOLUME/diffusion-pipe-helper/toml_files" "$NETWORK_VOLUME/"
    # fi

    # Move toml_files folder and create backups (no path updates - already hardcoded)
    if [ -d "$NETWORK_VOLUME/diffusion-pipe-helper/toml_files" ]; then
        echo "Moving TOML files..."
        mv "$NETWORK_VOLUME/diffusion-pipe-helper/toml_files" "$NETWORK_VOLUME/"
        
        # Create backup of each TOML file
        for toml_file in "$NETWORK_VOLUME/toml_files"/*.toml; do
            if [ -f "$toml_file" ]; then
                cp "$toml_file" "$toml_file.backup"
                echo "Created backup: $(basename "$toml_file").backup"
            fi
        done
    fi
fi

# Move diffusion_pipe if it exists in root to working directory
if [ -d "/diffusion_pipe" ]; then
    echo "Moving diffusion_pipe from root to working directory..."
    mv /diffusion_pipe "$NETWORK_VOLUME/"
fi

# Set up directory structure
DIFF_PIPE_DIR="$NETWORK_VOLUME/diffusion_pipe"

# Pull latest changes from diffusion_pipe repository
if [ -d "$DIFF_PIPE_DIR" ] && [ -d "$DIFF_PIPE_DIR/.git" ]; then
    echo "Pulling latest changes from diffusion_pipe repository..."
    cd "$DIFF_PIPE_DIR" || exit 1
    git pull || echo "Warning: Failed to pull latest changes from diffusion_pipe repository"
    cd "$NETWORK_VOLUME" || exit 1
else
    echo "Warning: diffusion_pipe directory not found or not a git repository. Skipping git pull."
fi

# Clean up examples and move dataset.toml
if [ -d "$NETWORK_VOLUME/diffusion_pipe/examples" ]; then
    rm -rf "$NETWORK_VOLUME/diffusion_pipe/examples"/*
    if [ -f "$NETWORK_VOLUME/diffusion-pipe-helper/dataset.toml" ]; then
        mv "$NETWORK_VOLUME/diffusion-pipe-helper/dataset.toml" "$NETWORK_VOLUME/diffusion_pipe/examples/"
    fi
fi

# Install Triton if requested
if [ "$download_triton" == "true" ]; then
    echo "Installing Triton..."
    pip install triton
fi

# Create dataset directories in the working directory
mkdir -p "$NETWORK_VOLUME/image_dataset_here"
mkdir -p "$NETWORK_VOLUME/video_dataset_here"
mkdir -p "$NETWORK_VOLUME/logs"
mkdir -p "$NETWORK_VOLUME/training_outputs"
# Update dataset.toml path to use the working directory
if [ -f "$NETWORK_VOLUME/diffusion_pipe/examples/dataset.toml" ]; then
    sed -i "s|path = '/home/anon/data/images/grayscale'|path = '$NETWORK_VOLUME/image_dataset_here'|" "$NETWORK_VOLUME/diffusion_pipe/examples/dataset.toml"
fi

echo "Installing torch"
pip install torch torchvision torchaudio

echo "Upgrading transformers package..."
pip install transformers -U

echo "Installing huggingface-cli..."
pip install --upgrade "huggingface_hub[cli]"

echo "Upgrading peft package..."
pip install --upgrade "peft>=0.17.0"

echo "Updating diffusers package..."
pip uninstall -y diffusers
pip install git+https://github.com/huggingface/diffusers

echo "================================================"
echo "✅ Jupyter Lab is running and accessible via the web interface"
echo "================================================"

sleep infinity
