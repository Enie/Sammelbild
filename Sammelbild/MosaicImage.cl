kernel void averageColor(global const uchar* data,
                         const int dataWidth,
                         const int dataHeight,
                         const int cropWidth,
                         const int cropHeith,
                         global float4* avgComponents)
{
    size_t i = get_global_id(0);
    int cropX = i*cropWidth%dataWidth;
    int cropY = floor((float)i*(1.0/(float)dataWidth/(float)cropWidth));
    
    int pixelCount = cropWidth*cropHeith;
    
    int xOffset, yOffset;
    int4 rgbComponents;
    
    for (int y = 0; y < cropHeith; y++)
    {
        yOffset = cropY+y;
        for (int x = 0; x < cropWidth; x++)
        {
            xOffset = (dataWidth*yOffset+x+cropX)*4;
            rgbComponents.x += data[xOffset+1];
            rgbComponents.y += data[xOffset+2];
            rgbComponents.z += data[xOffset+3];
            rgbComponents.w += data[xOffset];
        }
    }
    
    avgComponents[i][0] = rgbComponents.x/(float)pixelCount/255.0;
    avgComponents[i][1] = rgbComponents.y/(float)pixelCount/255.0;
    avgComponents[i][2] = rgbComponents.z/(float)pixelCount/255.0;
    avgComponents[i][3] = rgbComponents.y/(float)pixelCount/255.0;
    
}