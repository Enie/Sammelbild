//
//  OpenCLHost.c
//  Sammelbild
//
//  Created by Enie Weiß on 08.12.12.
//  Copyright (c) 2012 Enie Weiß. All rights reserved.
//

#include <stdio.h>
#include <OpenCL/cl.h>
#include "MosaicImage.cl.h"

float** getImagesWithOpenCL (unsigned char* data, int dataWidth, int dataHeight, int cropWidth, int cropHeight) {
    char name[128];
    
    dispatch_queue_t queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_GPU,
                                                       NULL);
    if (queue == NULL) {
        queue = gcl_create_dispatch_queue(CL_DEVICE_TYPE_CPU, NULL);
    }
    
    cl_device_id gpu = gcl_get_device_id_with_dispatch_queue(queue);
    clGetDeviceInfo(gpu, CL_DEVICE_NAME, 128, name, NULL);
    fprintf(stdout, "Created a dispatch queue using the %s\n", name);
    
    int cols = floor(dataWidth/cropWidth);
    int rows = floor(dataHeight/cropHeight);
    int tilesNum = cols*rows;
    
    cl_float** colorsOut = (cl_float**)malloc(sizeof(cl_float*)*tilesNum*4);
    
    // Our test kernel takes two parameters: an input float array and an
    // output float array.  We can't send the application's buffers above, since
    // our CL device operates on its own memory space.  Therefore, we allocate
    // OpenCL memory for doing the work.  Notice that for the input array,
    // we specify CL_MEM_COPY_HOST_PTR and provide the fake input data we
    // created above.  This tells OpenCL to copy over our data into its memory
    // space before it executes the kernel.                                   [3]
    void* mem_in  = gcl_malloc(sizeof(cl_uchar) * dataWidth*dataHeight*4, data,
                               CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR);
    
    void* mem_out = gcl_malloc(sizeof(cl_float4) * tilesNum, NULL,
                               CL_MEM_WRITE_ONLY);
    
    // Dispatch your kernel block using one of the dispatch_ commands and the
    // queue we created above.                                                [5]
    
    dispatch_sync(queue, ^{
        
        // Though we COULD pass NULL as the workgroup size, which would tell
        // OpenCL to pick the one it thinks is best, we can also ask
        // OpenCL for the suggested size, and pass it ourselves.              [6]
        //size_t workgroup_size;
        //gcl_get_kernel_block_workgroup_info(square_kernel,
        //                                    CL_KERNEL_WORK_GROUP_SIZE,
        //                                    sizeof(workgroup_size), &workgroup_size, NULL);
        
        // The N-Dimensional Range over which we'd like to execute our
        // kernel.  In our example case, we're operating on a 1D buffer, so
        // it makes sense that our range is 1D.
        cl_ndrange range = {
            1,                     // The number of dimensions to use.
            
            {0, 0, 0},             // The offset in each dimension.  We want to
            // process ALL of our data, so this is 0 for
            // our test case.                          [7]
            
            {tilesNum, 0, 0},    // The global range -- this is how many items
            // IN TOTAL in each dimension you want to
            // process.
            
            {0,0,0}
            //{workgroup_size, 0, 0} // The local size of each workgroup.  This
            // determines the number of workitems per
            // workgroup.  It indirectly affects the
            // number of workgroups, since the global
            // size / local size yields the number of
            // workgroups.  So in our test case, we will
            // have NUM_VALUE / wgs workgroups.
        };
        // Calling the kernel is easy; you simply call it like a function,
        // passing the ndrange as the first parameter, followed by the expected
        // kernel parameters.  Note that we case the 'void*' here to the
        // expected OpenCL types.  Remember -- if you use 'float' in your
        // kernel, that's a 'cl_float' from the application's perspective.   [8]
        
        averageColor_kernel(&range,(cl_uchar*)mem_in,
                            dataWidth,
                            dataHeight,
                            cropWidth,
                            cropHeight,
                            (cl_float4*)mem_out);
        
        // Getting data out of the device's memory space is also easy; we
        // use gcl_memcpy.  In this case, we take the output computed by the
        // kernel and copy it over to our application's memory space.        [9]
        
        gcl_memcpy(colorsOut, mem_out, sizeof(cl_float) * tilesNum * 4);
        
    });
    
    // Don't forget to free up the CL device's memory when you're done.      [10]
    gcl_free(mem_in);
    gcl_free(mem_out);
    
    // Finally, release your queue just as you would any GCD queue.          [11]
    dispatch_release(queue);
    
    return colorsOut;
}