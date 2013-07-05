//
//  tree.c
//  Sammelbild
//
//  Created by Enie Weiß on 18.01.13.
//  Copyright (c) 2013 Enie Weiß. All rights reserved.
//

#include <stdio.h>

typedef struct {
    unsigned char value;
    int size;
    struct node** nodes;
} hue_node;

typedef struct {
    int size;
    struct node** nodes;
} saturation_node;

typedef struct {
    int size;
    struct node** nodes;
} brightness_node;

typedef struct {
    hue_node node;
} color_tree;

