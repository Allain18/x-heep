// Generated register defines for camera

#ifndef _CAMERA_REG_DEFS_
#define _CAMERA_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define CAMERA_PARAM_REG_WIDTH 32

// Control register for flash controller
#define CAMERA_CONTROL_REG_OFFSET 0x0
#define CAMERA_CONTROL_START_BIT 0

// Status register for flash controller
#define CAMERA_STATUS_REG_OFFSET 0x4
#define CAMERA_STATUS_RUNNING_BIT 0

// Memory area: Camera data window.
#define CAMERA_DATA_REG_OFFSET 0x8
#define CAMERA_DATA_SIZE_WORDS 1
#define CAMERA_DATA_SIZE_BYTES 4
#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _CAMERA_REG_DEFS_
// End generated register defines for camera