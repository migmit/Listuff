#!/bin/sh

#  generate_pictures.sh
#  Listuff
#
#  Created by MigMit on 17.01.2021.
#  

arcs=blue; background=lightgray; extras=gray; convert -size 1024x1024 xc:$background -strokewidth 16 -stroke $arcs -fill $background -draw 'translate 512,0 skewY 30 ellipse -336,512 144,192 0,360' -stroke $background -strokewidth 0 -draw 'translate 512,0 rectangle -336,0 512,1024' -stroke $arcs -strokewidth 16 -draw 'translate 512,0 skewY 30 ellipse -144,512 48,64 0,360' -stroke $background -strokewidth 0 -draw 'translate 512,0 rectangle -144,0 512,1024' -stroke $arcs -strokewidth 16 -draw 'translate 512,0 skewY 30 ellipse 384,576 96,128 0,360' -stroke $background -strokewidth 0 -draw 'translate 512,0 rectangle 0,0 384,1024' -stroke black -fill black -draw 'translate 512,0 skewY 30 rectangle -192,312 154,328 rectangle 0,440 327,456 rectangle 0,568 218,584 rectangle -192,696 327,712 ellipse -264,320 15,20 0,360 ellipse -72,448 15,20 0,360 ellipse -72,576 15,20 0,360 ellipse -264,704 15,20 0,360' -stroke $extras -fill $extras -draw 'translate 512,0 skewY 30 rectangle -279,56 327,72 rectangle -279,184 327,200 rectangle -279,824 327,840 rectangle -279,952 327,968' 1024x1024.png
