#!/bin/sh

#  generate_pictures.sh
#  Listuff
#
#  Created by MigMit on 17.01.2021.
#  

arcs=blue
background=lightgray
extras=gray
convert -size 1024x1024 xc:$background -strokewidth 16 -stroke $arcs -fill $background -draw 'translate 512,0 skewY 30 ellipse -336,512 144,192 0,360' -stroke $background -strokewidth 0 -draw 'translate 512,0 rectangle -336,0 512,1024' -stroke $arcs -strokewidth 16 -draw 'translate 512,0 skewY 30 ellipse -144,512 48,64 0,360' -stroke $background -strokewidth 0 -draw 'translate 512,0 rectangle -144,0 512,1024' -stroke $arcs -strokewidth 16 -draw 'translate 512,0 skewY 30 ellipse 384,576 96,128 0,360' -stroke $background -strokewidth 0 -draw 'translate 512,0 rectangle 0,0 384,1024' -stroke black -fill black -draw 'translate 512,0 skewY 30 rectangle -192,312 154,328 rectangle 0,440 327,456 rectangle 0,568 218,584 rectangle -192,696 327,712 ellipse -264,320 15,20 0,360 ellipse -72,448 15,20 0,360 ellipse -72,576 15,20 0,360 ellipse -264,704 15,20 0,360' -stroke $extras -fill $extras -draw 'translate 512,0 skewY 30 rectangle -279,56 327,72 rectangle -279,184 327,200 rectangle -279,824 327,840 rectangle -279,952 327,968' 1024x1024.png
convert -size 180x180 xc:$background -strokewidth 3 -stroke $arcs -fill $background -draw 'translate 90,0 skewY 30 ellipse -59,90 25,34 0,360' -stroke $background -strokewidth 0 -draw 'translate 90,0 rectangle -59,0 90,180' -stroke $arcs -strokewidth 3 -draw 'translate 90,0 skewY 30 ellipse -25,90 8,11 0,360' -stroke $background -strokewidth 0 -draw 'translate 90,0 rectangle -25,0 90,180' -stroke $arcs -strokewidth 3 -draw 'translate 90,0 skewY 30 ellipse 68,101 17,23 0,360' -stroke $background -strokewidth 0 -draw 'translate 90,0 rectangle 0,0 68,180' -stroke black -fill black -draw 'translate 90,0 skewY 30 rectangle -34,55 27,58 rectangle 0,77 57,80 rectangle 0,100 38,103 rectangle -34,122 57,125 ellipse -46,56 3,4 0,360 ellipse -13,79 3,4 0,360 ellipse -13,101 3,4 0,360 ellipse -46,124 3,4 0,360' -stroke $extras -fill $extras -draw 'translate 90,0 skewY 30 rectangle -49,10 57,13 rectangle -49,32 57,35 rectangle -49,145 57,148 rectangle -49,167 57,170' 180x180.png
convert -size 167x167 xc:$background -strokewidth 3 -stroke $arcs -fill $background -draw 'translate 84,0 skewY 30 ellipse -55,84 23,31 0,360' -stroke $background -strokewidth 0 -draw 'translate 84,0 rectangle -55,0 84,167' -stroke $arcs -strokewidth 3 -draw 'translate 84,0 skewY 30 ellipse -23,84 8,10 0,360' -stroke $background -strokewidth 0 -draw 'translate 84,0 rectangle -23,0 84,167' -stroke $arcs -strokewidth 3 -draw 'translate 84,0 skewY 30 ellipse 63,94 16,21 0,360' -stroke $background -strokewidth 0 -draw 'translate 84,0 rectangle 0,0 63,167' -stroke black -fill black -draw 'translate 84,0 skewY 30 rectangle -31,51 25,53 rectangle 0,72 53,74 rectangle 0,93 36,95 rectangle -31,114 53,116 ellipse -43,52 2,3 0,360 ellipse -12,73 2,3 0,360 ellipse -12,94 2,3 0,360 ellipse -43,115 2,3 0,360' -stroke $extras -fill $extras -draw 'translate 84,0 skewY 30 rectangle -46,9 53,12 rectangle -46,30 53,33 rectangle -46,134 53,137 rectangle -46,155 53,158' 167x167.png
convert -size 152x152 xc:$background -strokewidth 2 -stroke $arcs -fill $background -draw 'translate 76,0 skewY 30 ellipse -50,76 21,29 0,360' -stroke $background -strokewidth 0 -draw 'translate 76,0 rectangle -50,0 76,152' -stroke $arcs -strokewidth 2 -draw 'translate 76,0 skewY 30 ellipse -21,76 7,10 0,360' -stroke $background -strokewidth 0 -draw 'translate 76,0 rectangle -21,0 76,152' -stroke $arcs -strokewidth 2 -draw 'translate 76,0 skewY 30 ellipse 57,86 14,19 0,360' -stroke $background -strokewidth 0 -draw 'translate 76,0 rectangle 0,0 57,152' -stroke black -fill black -draw 'translate 76,0 skewY 30 rectangle -29,46 23,49 rectangle 0,65 49,68 rectangle 0,84 32,87 rectangle -29,103 49,106 ellipse -39,48 2,3 0,360 ellipse -11,67 2,3 0,360 ellipse -11,86 2,3 0,360 ellipse -39,105 2,3 0,360' -stroke $extras -fill $extras -draw 'translate 76,0 skewY 30 rectangle -41,8 49,11 rectangle -41,27 49,30 rectangle -41,122 49,125 rectangle -41,141 49,144' 152x152.png
convert -size 120x120 xc:$background -strokewidth 2 -stroke $arcs -fill $background -draw 'translate 60,0 skewY 30 ellipse -39,60 17,23 0,360' -stroke $background -strokewidth 0 -draw 'translate 60,0 rectangle -39,0 60,120' -stroke $arcs -strokewidth 2 -draw 'translate 60,0 skewY 30 ellipse -17,60 6,8 0,360' -stroke $background -strokewidth 0 -draw 'translate 60,0 rectangle -17,0 60,120' -stroke $arcs -strokewidth 2 -draw 'translate 60,0 skewY 30 ellipse 45,68 11,15 0,360' -stroke $background -strokewidth 0 -draw 'translate 60,0 rectangle 0,0 45,120' -stroke black -fill black -draw 'translate 60,0 skewY 30 rectangle -23,37 18,38 rectangle 0,52 38,53 rectangle 0,67 26,68 rectangle -23,82 38,83 ellipse -31,38 2,3 0,360 ellipse -8,53 2,3 0,360 ellipse -8,68 2,3 0,360 ellipse -31,83 2,3 0,360' -stroke $extras -fill $extras -draw 'translate 60,0 skewY 30 rectangle -33,7 38,8 rectangle -33,22 38,23 rectangle -33,97 38,98 rectangle -33,112 38,113' 120x120.png
convert -size 87x87 xc:$background -strokewidth 1 -stroke $arcs -fill $background -draw 'translate 43,0 skewY 30 ellipse -29,44 12,16 0,360' -stroke $background -strokewidth 0 -draw 'translate 43,0 rectangle -29,0 44,87' -stroke $arcs -strokewidth 1 -draw 'translate 43,0 skewY 30 ellipse -12,44 4,5 0,360' -stroke $background -strokewidth 0 -draw 'translate 43,0 rectangle -12,0 44,87' -stroke $arcs -strokewidth 1 -draw 'translate 43,0 skewY 30 ellipse 33,49 8,11 0,360' -stroke $background -strokewidth 0 -draw 'translate 43,0 rectangle 0,0 33,87' -strokewidth 1 -stroke black -fill black -draw 'translate 43,0 skewY 30 line -15,27 13,27 line 1,38 28,38 line 1,49 19,49 line -15,60 28,60 ellipse -22,27 1,2 0,360 ellipse -6,38 1,2 0,360 ellipse -6,49 1,2 0,360 ellipse -22,60 1,2 0,360' -stroke $extras -fill $extras -draw 'translate 43,0 skewY 30 line -24,5 28,5 line -24,16 28,16 line -24,71 28,71 line -24,82 28,82' 87x87.png
convert -size 80x80 xc:$background -strokewidth 1 -stroke $arcs -fill $background -draw 'translate 40,0 skewY 30 ellipse -26,40 11,14 0,360' -stroke $background -strokewidth 0 -draw 'translate 40,0 rectangle -26,0 40,80' -stroke $arcs -strokewidth 1 -draw 'translate 40,0 skewY 30 ellipse -11,40 4,5 0,360' -stroke $background -strokewidth 0 -draw 'translate 40,0 rectangle -11,0 40,80' -stroke $arcs -strokewidth 1 -draw 'translate 40,0 skewY 30 ellipse 29,45 8,10 0,360' -stroke $background -strokewidth 0 -draw 'translate 40,0 rectangle 0,0 29,80' -strokewidth 1 -stroke black -fill black -draw 'translate 40,0 skewY 30 line -15,25 11,25 line 0,35 25,35 line 0,45 16,45 line -15,55 25,55 ellipse -21,25 1,1 0,360 ellipse -6,35 1,1 0,360 ellipse -6,45 1,1 0,360 ellipse -21,55 1,1 0,360' -stroke $extras -fill $extras -draw 'translate 40,0 skewY 30 line -22,5 25,5 line -22,15 25,15 line -22,65 25,65 line -22,75 25,75' 80x80.png
convert -size 76x76 xc:$background -strokewidth 1 -stroke $arcs -fill $background -draw 'translate 38,0 skewY 30 ellipse -25,38 11,14 0,360' -stroke $background -strokewidth 0 -draw 'translate 38,0 rectangle -25,0 38,76' -stroke $arcs -strokewidth 1 -draw 'translate 38,0 skewY 30 ellipse -11,38 4,5 0,360' -stroke $background -strokewidth 0 -draw 'translate 38,0 rectangle -11,0 38,76' -stroke $arcs -strokewidth 1 -draw 'translate 38,0 skewY 30 ellipse 29,43 7,10 0,360' -stroke $background -strokewidth 0 -draw 'translate 38,0 rectangle 0,0 29,76' -strokewidth 1 -stroke black -fill black -draw 'translate 38,0 skewY 30 line -14,23 11,23 line 0,33 24,33 line 0,43 16,43 line -14,53 24,53 ellipse -20,23 1,1 0,360 ellipse -5,33 1,1 0,360 ellipse -5,43 1,1 0,360 ellipse -20,53 1,1 0,360' -stroke $extras -fill $extras -draw 'translate 38,0 skewY 30 line -21,3 24,3 line -21,13 24,13 line -21,63 24,63 line -21,73 24,73' 76x76.png
convert -size 60x60 xc:$background -strokewidth 1 -stroke $arcs -fill $background -draw 'translate 30,0 skewY 30 ellipse -21,30 7,10 0,360' -stroke $background -strokewidth 0 -draw 'translate 30,0 rectangle -20,0 30,60' -stroke $arcs -strokewidth 1 -draw 'translate 30,0 skewY 30 ellipse -8,30 3,4 0,360' -stroke $background -strokewidth 0 -draw 'translate 30,0 rectangle -8,0 30,60' -stroke $arcs -strokewidth 1 -draw 'translate 30,0 skewY 30 ellipse 23,33 5,7 0,360' -stroke $background -strokewidth 0 -draw 'translate 30,0 rectangle 0,0 22,60' -strokewidth 1 -stroke black -fill black -draw 'translate 30,0 skewY 30 line -10,19 9,19 line 1,26 19,26 line 1,33 13,33 line -10,40 19,40 ellipse -15,19 1,1 0,360 ellipse -4,26 1,1 0,360 ellipse -4,33 1,1 0,360 ellipse -15,40 1,1 0,360' -stroke $extras -fill $extras -draw 'translate 30,0 skewY 30 line -16,5 19,5 line -16,12 19,12 line -16,47 19,47 line -16,54 19,54' 60x60.png
convert -size 58x58 xc:$background -strokewidth 1 -stroke $arcs -fill $background -draw 'translate 29,0 skewY 30 ellipse -19,29 8,11 0,360' -stroke $background -strokewidth 0 -draw 'translate 29,0 rectangle -19,0 29,58' -stroke $arcs -strokewidth 1 -draw 'translate 29,0 skewY 30 ellipse -8,29 3,4 0,360' -stroke $background -strokewidth 0 -draw 'translate 29,0 rectangle -8,0 29,58' -stroke $arcs -strokewidth 1 -draw 'translate 29,0 skewY 30 ellipse 21,32 5,7 0,360' -stroke $background -strokewidth 0 -draw 'translate 29,0 rectangle 0,0 21,58' -strokewidth 1 -stroke black -fill black -draw 'translate 29,0 skewY 30 line -10,18 8,18 line 1,25 18,25 line 1,32 11,32 line -10,39 18,39 ellipse -15,18 1,1 0,360 ellipse -4,25 1,1 0,360 ellipse -4,32 1,1 0,360 ellipse -15,39 1,1 0,360' -stroke $extras -fill $extras -draw 'translate 29,0 skewY 30 line -16,4 18,4 line -16,11 18,11 line -16,46 18,46 line -16,53 18,53' 58x58.png
convert -size 40x40 xc:$background -strokewidth 1 -stroke $arcs -fill $background -draw 'translate 20,0 skewY 30 ellipse -14,20 5,7 0,360' -stroke $background -strokewidth 0 -draw 'translate 20,0 rectangle -14,0 20,40' -stroke $arcs -strokewidth 1 -draw 'translate 20,0 skewY 30 ellipse -8,20 2,3 0,360' -stroke $background -strokewidth 0 -draw 'translate 20,0 rectangle -7,0 20,40' -stroke $arcs -strokewidth 1 -draw 'translate 20,0 skewY 30 ellipse 14,22 4,5 0,360' -stroke $background -strokewidth 0 -draw 'translate 20,0 rectangle 0,0 14,40' -strokewidth 1 -stroke black -fill black -draw 'translate 20,0 skewY 30 line -11,12 3,12 line -4,17 11,17 line -4,22 6,22 line -11,27 11,27' -stroke $extras -fill $extras -draw 'translate 20,0 skewY 30 line -11,2 11,2 line -11,7 11,7 line -11,32 11,32 line -11,37 11,37' 40x40.png
convert -size 29x29 xc:$background -strokewidth 1 -stroke $arcs -fill $background -draw 'translate 14,-5 skewY 30 ellipse -9,19 5,6 0,360' -stroke $background -strokewidth 0 -draw 'translate 14,-5 rectangle -9,0 20,40' -stroke $arcs -strokewidth 1 -draw 'translate 14,-5 skewY 30 ellipse -4,19 2,2 0,360' -stroke $background -strokewidth 0 -draw 'translate 14,-5 rectangle -3,0 20,40' -stroke $arcs -strokewidth 1 -draw 'translate 14,-5 skewY 30 ellipse 10,21 4,4 0,360' -stroke $background -strokewidth 0 -draw 'translate 14,-5 rectangle 0,0 10,40' -strokewidth 1 -stroke black -fill black -draw 'translate 14,-5 skewY 30 line -7,13 3,13 line -1,17 8,17 line -1,21 5,21 line -7,25 8,25' -stroke $extras -fill $extras -draw 'translate 14,-5 skewY 30 line -7,5 8,5 line -7,9 8,9 line -7,29 8,29 line -7,33 8,33' 29x29.png
convert -size 20x20 xc:$background -strokewidth 1 -stroke $arcs -fill $background -draw 'translate 10,-9 skewY 30 ellipse -5,19 5,6 0,360' -stroke $background -strokewidth 0 -draw 'translate 10,-9 rectangle -4,0 20,40' -stroke $arcs -strokewidth 1 -draw 'translate 10,-9 skewY 30 ellipse -3,19 2,2 0,360' -stroke $background -strokewidth 0 -draw 'translate 10,-9 rectangle -2,0 20,40' -stroke $arcs -strokewidth 1 -draw 'translate 10,-9 skewY 30 ellipse 5,21 4,4 0,360' -stroke $background -strokewidth 0 -draw 'translate 10,-9 rectangle 0,0 5,40' -strokewidth 1 -stroke black -fill black -draw 'translate 10,-9 skewY 30 line -4,13 2,13 line -2,17 5,17 line -2,21 3,21 line -4,25 5,25' 20x20.png
