# 🧪 Testing Guide

## Testing on Windows (Development Environment)

You can test the UI and menu system right now on your Windows machine!

### 1. Install Dependencies

```powershell
pip install rich
```

### 2. Test the Python Script

```powershell
cd "c:\Users\User\Downloads\whatever\FINAL-CODE\diffusion-pipe-helper"
python interactive_start_training.py
```

### What You'll See

✅ **Beautiful welcome banner** with cyan colors
✅ **Interactive menu** with 7 models in a table
✅ **Model selection prompt** with validation
✅ **API token prompt** (for FLUX)
✅ **Caption mode selection**
✅ **Configuration summary** panel

❌ **Will fail at:** Download/training (needs Linux + GPU)

### Expected Output

```
╭─────────────────────────────────────────────────────╮
│  Diffusion Pipe Helper - Interactive Training       │
│  A Python version with Rich UI                      │
╰─────────────────────────────────────────────────────╯

┌─────────────────────────────────────────────────────┐
│              Select Model to Train                  │
├───┬──────────────────────────────┬─────────────────┤
│ # │ Model                        │ Type            │
├───┼──────────────────────────────┼─────────────────┤
│ 1 │ Flux                         │ Image           │
│ 2 │ SDXL                         │ Image           │
│ 3 │ Wan 1.3B                     │ Video           │
│ 4 │ Wan 14B Text-To-Video        │ Video           │
│ 5 │ Wan 14B Image-To-Video       │ Video           │
│ 6 │ Qwen Image                   │ Image           │
│ 7 │ Z Image Turbo                │ Image           │
└───┴──────────────────────────────┴─────────────────┘

Enter your choice [1/2/3/4/5/6/7] (1):
```

---

## Testing on Linux (Without GPU)

Test everything except actual training:

### 1. Setup Mock Environment

```bash
# Create mock workspace
export NETWORK_VOLUME=/tmp/test_workspace
mkdir -p $NETWORK_VOLUME

# Create mock diffusion_pipe
mkdir -p /tmp/diffusion_pipe

# Run setup
bash setup.sh
```

### 2. Test Menu

```bash
cd $NETWORK_VOLUME/diffusion-pipe-working-folder
python interactive_start_training.py
```

You can navigate through:
- ✅ Menu selection
- ✅ Token input
- ✅ Caption mode
- ✅ Dataset validation (will warn about missing files)
- ✅ Configuration summary

❌ Will fail at training (no GPU)

---

## Testing on Real GPU Environment (Full Test)

### Prerequisites

- Ubuntu 24.04
- CUDA 12.8+
- GPU (H100/H200 recommended)
- HuggingFace CLI installed

### 1. Full Setup

```bash
# Set environment
export NETWORK_VOLUME=/workspace

# Clone repo (when available)
git clone https://github.com/yourusername/diffusion-pipe-helper
cd diffusion-pipe-helper

# Run setup
bash setup.sh
```

### 2. Add Test Dataset

```bash
# Create test images (or use real ones)
mkdir -p /workspace/image_dataset_here
# Copy your images here

# Optional: Create test videos
mkdir -p /workspace/video_dataset_here
# Copy your videos here
```

### 3. Test with SDXL (No Token Required)

```bash
cd /workspace/diffusion-pipe-working-folder
bash start_training.sh
```

Select option `2` (SDXL) - this doesn't need a HuggingFace token!

### 4. Monitor Training

```bash
# In another terminal, watch the download log
tail -f /workspace/logs/model_download.log

# Watch GPU usage
watch -n 1 nvidia-smi
```

### Expected Timeline

1. **Menu (5 seconds)** - Select model, choose options
2. **Validation (2 seconds)** - Check dataset
3. **Download (10-60 minutes)** - Depends on model size and internet
4. **Training (hours)** - Depends on dataset size and GPU

---

## What to Test

### ✅ UI Features

- [ ] Welcome banner displays correctly
- [ ] Menu table is formatted nicely
- [ ] Model selection works (1-7)
- [ ] Token input is hidden (password field)
- [ ] Caption mode selection works
- [ ] Configuration summary shows all details
- [ ] Confirmation prompt works
- [ ] Colors display correctly (cyan, green, yellow, red)

### ✅ Functionality

- [ ] Directory structure created correctly
- [ ] Training scripts copied
- [ ] TOML files copied with updated paths
- [ ] Python script is executable
- [ ] Dataset validation finds images/videos
- [ ] API token is saved to environment
- [ ] Download starts in background
- [ ] Training launches after download

### ✅ Error Handling

- [ ] Missing Rich library - shows clear error
- [ ] Missing diffusion_pipe - shows helpful message
- [ ] Empty dataset - warns but allows continue
- [ ] Cancelled by user (Ctrl+C) - exits cleanly
- [ ] Download timeout (3 hours) - exits with error
- [ ] Invalid menu choice - prompts again

---

## Quick Smoke Tests

### Test 1: UI Only (5 minutes)

```powershell
# On Windows
pip install rich
python interactive_start_training.py

# Just navigate through menus, then Ctrl+C
```

Expected: ✅ Beautiful UI, ❌ Fails at download

---

### Test 2: Setup Only (2 minutes)

```bash
# On Linux
bash setup.sh

# Check folders created
ls -la /workspace/diffusion-pipe-working-folder
```

Expected: ✅ All folders created, files copied

---

### Test 3: Quick Training Script (1 minute)

```bash
# Skip interactive menu, use direct script
cd /workspace/diffusion-pipe-working-folder/training_scripts

# This will fail without model, but tests the script works
bash start_flux_training.sh
```

Expected: ❌ "Checkpoint doesn't exist" (correct behavior)

---

## Common Issues During Testing

### Issue: "Rich not found"
**Solution:**
```bash
pip install rich
```

### Issue: "Permission denied"
**Solution:**
```bash
chmod +x setup.sh
chmod +x start_training.sh
chmod +x interactive_start_training.py
```

### Issue: "diffusion_pipe not found"
**Expected:** This is normal if testing without Docker. Setup script will show warning.

### Issue: "CUDA not available"
**Expected:** Training will fail on CPU-only systems. This is correct behavior.

---

## Validation Checklist

Before deploying to production:

- [ ] All files copied correctly
- [ ] Paths updated in TOML files
- [ ] setup.sh creates correct structure
- [ ] interactive_start_training.py runs without errors
- [ ] Rich UI displays properly
- [ ] Menu accepts all valid inputs (1-7)
- [ ] Can test with SDXL (no token needed)
- [ ] Downloads work with HuggingFace CLI
- [ ] Training launches successfully
- [ ] Output files created in correct location

---

## Performance Testing

### Download Speed Test

```bash
# Time the SDXL download (smallest model ~2GB)
time bash start_training.sh
# Select SDXL, skip captioning
```

Expected: 5-15 minutes depending on internet

### Training Speed Test

```bash
# Small dataset (10 images, 100 steps)
# Edit sdxl.toml: epochs = 1, steps = 100
python interactive_start_training.py
```

Expected: 10-30 minutes on H100

---

## Advanced Testing

### Test All 7 Models

Create a test script:

```bash
#!/bin/bash
# test_all_models.sh

for model in flux sdxl wan13 wan14b_t2v wan14b_i2v qwen z_image_turbo; do
    echo "Testing $model..."
    # Run download only, no training
    # Add --dry-run flag or modify script
done
```

### Stress Test

```bash
# Large dataset (1000+ images)
# Monitor memory usage
# Check for memory leaks
```

---

## Result: You're Ready! 🎉

If you can:
1. ✅ See the Rich UI on Windows
2. ✅ Navigate through menus
3. ✅ Setup creates folders correctly

Then the code is **WORKING**!

For full testing, you need:
- Linux with CUDA
- HuggingFace CLI
- GPU (for training)

But you can validate the UI and logic **right now on Windows**! 🚀
