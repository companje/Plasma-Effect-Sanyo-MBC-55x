org 0
cpu 8086

STAGE2_SEG equ 0x1000
ASSET_SEG  equ 0x1800

boot:
  cli
  cld

  mov ax,cs
  mov ds,ax
  mov ss,ax
  mov sp,0x0200

  mov ax,STAGE2_SEG
  mov es,ax
  xor di,di
  mov dl,0                  ; track
  mov dh,2                  ; sector after the boot sector
  mov cx,SECTORS
  call read_sectors

  jmp STAGE2_SEG:0

read_sectors:
  jmp move_head

next_sector:
  jmp move_head

advance_disk_sector:
  inc dh
  cmp dh,10                 ; sectors 1..9
  jb .return
  mov dh,1
  inc dl
.return:
  ret

move_head:
  mov al,dl
  out 0eh,al                ; track number
  mov al,18h
  out 8,al                  ; seek track, load head
  xor al,al
  out 1ch,al                ; drive/side
  aam                       ; short delay

head_moving:
  in al,8
  test al,1
  jnz head_moving

read_sector:
  mov al,dh
  out 0ch,al                ; sector number
  mov bh,2
  mov bl,96h
  xor ah,ah
  mov al,80h
  out 8,al                  ; read sector
  times 4 aam

check_status_1:
  in al,8
  sar al,1
  jnb check_status_3
  jnz check_status_1

wait_for_data:
  in al,8
  and al,bl
  jz wait_for_data
  in al,0eh
  stosb

check_status_2:
  in al,8
  dec ax
  jz check_status_2
  cmp al,bh
  jnz check_status_3

store_byte_2:
  in al,0eh
  stosb

check_status_4:
  in al,8
  cmp al,bh
  jz store_byte_2
  jmp check_status_2

check_status_3:
  in al,8
  test al,1ch
  jz sector_done
  jmp read_sector

sector_done:
  call advance_load_segment
  call advance_disk_sector
  loop next_sector
  ret

advance_load_segment:
  or di,di
  jnz .return
  mov ax,es
  add ax,0x1000
  mov es,ax
.return:
  ret

sectors_done:
  dw 0

%assign boot_size $-$$
%if boot_size > 512
  %error bootloader exceeds 512 bytes
%endif

times 512-($-$$) db 0
