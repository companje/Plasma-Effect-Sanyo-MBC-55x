%ifndef VIDEO_ASM
%define VIDEO_ASM

RED_SEG   equ 0f000h
GREEN_SEG equ 0800h
BLUE_SEG  equ 0f400h
PLANE_SIZE equ 16384

SCREEN_WIDTH           equ 640
SCREEN_HEIGHT          equ 200
BYTES_PER_SCAN_GROUP   equ 320

; 0x3000:0000..090F is conventional RAM with -ramsize 256K. It is separate
; from the boot sector, the stage-2 load area (0x1000), and the RGB planes.
LUT_SEG                equ 3000h
Y_BASE                 equ 0
X_OFFSET               equ Y_BASE + SCREEN_HEIGHT * 2
PIXEL_MASK             equ X_OFFSET + SCREEN_WIDTH * 2
LUT_SIZE               equ PIXEL_MASK + SCREEN_WIDTH

; Initialiseert de 640×200-videomodus en start met een zwart scherm.
setup_video:
  mov al,4
  out 10h,al

  mov si,crtc_regs
  xor bx,bx
.next_crtc_reg:
  mov al,bl
  out 30h,al
  lodsb
  out 32h,al
  inc bl
  cmp bl,crtc_regs_end-crtc_regs
  jb .next_crtc_reg

  call clear_screen
  call build_pixel_luts ; dit zorgt dat je via de LUT sneller pixels kunt tekenen
  ret

crtc_regs:
  ; 80 character clocks × 8 pixels = 640 visible physical pixels.
  db 112,80,89,72,65,0,50,56,0,3,0,0,0,0
crtc_regs_end:

; Bouw de tabellen in conventioneel RAM nadat stage 2 is gestart.
; offset = (y & 3) + 320 * (y >> 2) + 4 * (x >> 3)
build_pixel_luts:
  mov ax,LUT_SEG
  mov es,ax

  xor bx,bx
  xor di,di
.y_loop:
  mov si,bx
  and si,3
  mov ax,bx
  shr ax,1
  shr ax,1
  mov cx,BYTES_PER_SCAN_GROUP
  mul cx
  add ax,si
  mov [es:Y_BASE+di],ax
  add di,2
  inc bx
  cmp bx,SCREEN_HEIGHT
  jb .y_loop

  xor bx,bx
.x_loop:
  mov ax,bx
  shr ax,1
  shr ax,1
  shr ax,1
  shl ax,1
  shl ax,1
  mov di,bx
  shl di,1
  mov [es:X_OFFSET+di],ax

  mov cl,bl
  and cl,7
  mov al,80h
  shr al,cl
  mov [es:PIXEL_MASK+bx],al
  inc bx
  cmp bx,SCREEN_WIDTH
  jb .x_loop
  ret

clear_screen:
  mov ax,RED_SEG
  call clear_plane
  mov ax,GREEN_SEG
  call clear_plane
  mov ax,BLUE_SEG
  call clear_plane
  ret

clear_plane:
  mov es,ax
  xor di,di
  xor ax,ax
  mov cx,PLANE_SIZE / 2
  rep stosw
  ret

; AX = RGB-plane segment, BX = x (0..639), SI = y (0..199).
set_pixel:
  push ds
  mov es,ax
  mov ax,LUT_SEG
  mov ds,ax
  shl si,1
  mov di,[Y_BASE+si]
  shl bx,1
  add di,[X_OFFSET+bx]
  shr bx,1
  mov al,[PIXEL_MASK+bx]
  or [es:di],al
  pop ds
  ret

%endif
