# Diffusion Pipe Helper

A Python-based interactive training assistant for diffusion-pipe with a beautiful Rich UI.

## 🎯 Features

- ✅ **Beautiful Rich UI** - Tables, panels, progress bars instead of plain text
- ✅ **Interactive Menu** - Easy model selection
- ✅ **Embedded Downloads** - Automatic model downloading from HuggingFace
- ✅ **Dataset Validation** - Check your dataset before training
- ✅ **Background Downloads** - Download models while doing other tasks
- ✅ **Same Functionality** - All features from original bash script
- ✅ **75% Less Code** - 300 lines vs 1224 lines

## 📁 Structure

```
diffusion-pipe-helper/
├── setup.sh                        # Environment setup
├── start_training.sh               # Quick launch wrapper
├── interactive_start_training.py   # Main Python script (Rich UI)
├── training_scripts/               # 5 training launchers (copied from original)
│   ├── start_flux_training.sh
│   ├── start_sdxl_training.sh
│   ├── start_wan_t2v_13b_training.sh
│   ├── start_wan_t2v_14b_training.sh
│   └── start_wan_i2v_480p_training.sh
└── toml_files/                     # Training configs (updated paths)
    ├── flux.toml
    ├── sdxl.toml
    ├── wan13_video.toml
    ├── wan14b_t2v.toml
    ├── wan14b_i2v.toml
    ├── qwen_toml.toml
    └── z_image_toml.toml
```

## 🚀 Quick Start

### 1. Setup Environment

```bash
# Run setup once to create folders and install dependencies
bash setup.sh
```

This will:
- Create `/workspace/diffusion-pipe-working-folder/`
- Create dataset folders (`image_dataset_here`, `video_dataset_here`)
- Copy all files to working directory
- Install Python dependencies (Rich)
- Configure auto-cd to working directory

### 2. Add Your Dataset

```bash
# Add training images
cp your_images/* /workspace/image_dataset_here/

# Add training videos (if needed)
cp your_videos/* /workspace/video_dataset_here/
```

### 3. Start Training

```bash
cd /workspace/diffusion-pipe-working-folder
bash start_training.sh
```

## 🎮 How to Use

### Interactive Training (Recommended for beginners)

```bash
bash start_training.sh
```

Follow the prompts:
1. Select model (1-7)
2. Enter API token (if required)
3. Choose captioning mode
4. Confirm configuration
5. Wait for download
6. Training starts automatically!

### Quick Launch (For experienced users)

If you already have models downloaded and just want to restart training:

```bash
# For FLUX
bash training_scripts/start_flux_training.sh

# For SDXL
bash training_scripts/start_sdxl_training.sh

# For WAN 1.3B
bash training_scripts/start_wan_t2v_13b_training.sh

# etc...
```

## 📝 Supported Models

| # | Model | Type | Token Required |
|---|-------|------|----------------|
| 1 | Flux | Image | Yes (HuggingFace) |
| 2 | SDXL | Image | No |
| 3 | Wan 1.3B | Video | No |
| 4 | Wan 14B T2V | Video | No |
| 5 | Wan 14B I2V | Video | No |
| 6 | Qwen Image | Image | No |
| 7 | Z Image Turbo | Image | No |

## 🧪 Testing Locally (Without GPU)

You can test the UI and menu system without a GPU:

```bash
# 1. Install dependencies
pip install rich

# 2. Run the script (will fail at training but you can test the UI)
python interactive_start_training.py
```

The script will:
- ✅ Show menu
- ✅ Accept your selection
- ✅ Validate dataset
- ✅ Show configuration
- ❌ Fail at download/training (needs HuggingFace CLI and GPU)

### Testing on Windows (Development)

```powershell
# Install Rich
pip install rich

# Test the Python script
python interactive_start_training.py

# You'll see the beautiful Rich UI!
```

## 🔧 Configuration

### Environment Variables

```bash
# Working directory (default: /workspace)
export NETWORK_VOLUME=/workspace

# HuggingFace token (for FLUX model)
export HUGGING_FACE_TOKEN=your_token_here
```

### TOML Files

All training configurations are in `toml_files/`:
- Paths updated to `/workspace/diffusion-pipe-working-folder/`
- Output goes to `/workspace/diffusion-pipe-working-folder/output_folder/`

Edit these files to customize:
- Batch size
- Learning rate
- Training epochs
- Model parameters

## 📊 Comparison with Original

| Feature | Original Bash | Our Python |
|---------|--------------|------------|
| **Lines of Code** | 1224 lines | 300 lines |
| **UI** | Plain echo | Rich tables/panels |
| **Menu** | Text numbers | Formatted table |
| **Progress** | Dots | Progress bars |
| **Error Messages** | Plain text | Colored panels |
| **Functionality** | Full | Full (same) |

## 🐛 Troubleshooting

### "Rich library not found"
```bash
pip install rich
```

### "diffusion_pipe directory not found"
Run `setup.sh` first!

### "HuggingFace CLI not found"
```bash
pip install huggingface_hub[cli]
```

### "CUDA not available"
Make sure you're running on a GPU instance with CUDA 12.8+

### Download stuck or slow
Check log file:
```bash
tail -f /workspace/logs/model_download.log
```

## 📝 Notes

- **First run takes longer** - Models are 2-50GB and need to download
- **Subsequent runs are fast** - Models are cached
- **Background downloads** - You can monitor while it downloads
- **3 hour timeout** - Large models have extended timeout
- **Auto-validation** - Checks dataset before starting

## 🎯 Next Steps

After training completes:
1. Find your LoRA in `/workspace/diffusion-pipe-working-folder/output_folder/`
2. Model files are `.safetensors` format
3. Use with ComfyUI, Automatic1111, or other inference tools

## 📚 Additional Resources

- Original repo: [tdrussell/diffusion-pipe](https://github.com/tdrussell/diffusion-pipe)
- Helper scripts: [Hearmeman24/runpod-diffusion_pipe](https://github.com/Hearmeman24/runpod-diffusion_pipe)
- Rich library: [Textualize/rich](https://github.com/Textualize/rich)

## 🤝 Credits

- Training engine: tdrussell/diffusion-pipe
- Original helper scripts: Hearmeman24
- Python version: Community contribution

## 📄 License

Same as original projects (check individual repos for details)
