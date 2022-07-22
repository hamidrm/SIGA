# SIGA
SImple Graphic Accelerator

A 2D graphic accelerator from scratch. This project doesn't use any IP core.
The written SDRAM controller, uses burst commands as far as possible.

Current drawing abilities:
 - Filling rectangle
 - Drawing line (by bresenham algorithm)
 - Drawing circle (by bresenham algorithm)
 - Filling circle (by bresenham algorithm)
 
I will work on adding triangles drawing, alpha-blending, and anti-aliasing.

---
There's an example in this repo to showing current status. I used a cheap Spartan6 board named ESPIER_III V105 (labels in Chinese that marked on its corner). You can find its schematic [here](document/Espier_III-Schematic.pdf).
This board has a xc6slx9-2tqg144c (It seems this type hasn't internal hard DDR controller) and a w9864g6kh as SDRAM.
I have brought some images of this example below.
![img1](document/1658323557929.jpg)
![img2](document/1658323557936.jpg)
