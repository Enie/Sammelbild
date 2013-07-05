Sammelbild
==========

What can you do with Sammelbild?
Sammelbild will fastly create mosaics of an image (or a folder containing images), using the images from another folder as mosaic tiles. With a few parameters you can change the quality of the result. Set the image and tile size, whether to use images for the tiles or just fill them with colors and how far the same tile image shall be apart from itself in the image.

How to use Sammelbild
Firstly, add a reference image to be converted to a mosaic. Secondly, add an image folder with source images used for the tiles in the mosaic. Thirdly, tune the settings to get a decent result. If you get tiles where no images were filled but instead the original image shines through, you have two choices:

Add more images to your source images.
If you don't have more images that you can use you have to increase the tolerance.
That means Sammelbild will select an image for this tile, even though it is not a perfect fit. To get perfect fits for all possible tiles you'd need an image collection of several million images that are all different in their average color. Of course that's rather improbable, but still a bigger image set provides you with better results.

What the future holds
Once an image set was precomputed, creating mosaics can be pretty fast. Actually in real time. The goal is to use that feature to mosaicize Syphon streams.
