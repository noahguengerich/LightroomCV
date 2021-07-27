# LightroomCV

LightroomCV is an Adobe Lightroom plugin that aids library organization by automatically generating captions for images and applying them to the caption metadata field. The images can then be organized and searched within Lightroom using this generated caption. All processing is done on the local machine and supports either GPU or CPU acceleration.

This plugin implements a ResNet-101 decoder and an LSTM endoder with the *[Show, Attend, and Tell](https://arxiv.org/abs/1502.03044)* attention mechanism. It was created as a project for ECE 499 at the University of Victoria.

## Dependencies
The following dependencies are needed for LightroomCV:
* [Anaconda](https://www.anaconda.com/)  

Used for managing the python environment. The individual edition is fine.    

* [Cuda Toolkit 10.2](https://developer.nvidia.com/cuda-10.2-download-archive)

Not strictly required but greatly improves captioning performance by enabling GPU processing. Must have an NVIDIA GPU. Ensure you install version 10.2 and both patches. Note that if your GPU has less than 4GB of memory, then CUDA may run out of memory. If that's the case, change the `force_cpu` flag at the top of caption.py to `True` to force CPU processing.

## Installation

1. Clone this repository to your local machine

     `> git clone https://github.com/noahguengerich/LightroomCV`

2. Change directory to the captioner folder and install the conda environment:

    `> conda env create -f conda_environment.yml`

3. Open `captioner_start.bat ` and ensure that CONDAPATH and ENVFOLD are correct for your local machine. CONDAPATH is your conda installation location and ENVFOLD is where your environments are stored. 
4. Download the model weights file (~800 MB) from [here](https://drive.google.com/file/d/1IYI2GV6eqdjLy91rmUp_vXCn-c3ietgD/view?usp=sharing) and put it in the `captioner` folder.
5. Open Lightroom and navigate to the plug-in manager (`ctrl-alt-shift-,` or file -> plug-in manager). Click add and import the LightroomCV.lrplugin folder.

## Usage
The plugin menu can be accessed via Library -> Plug-in Extras -> Caption Images. From there, using the plugin is pretty self-explanatory.
