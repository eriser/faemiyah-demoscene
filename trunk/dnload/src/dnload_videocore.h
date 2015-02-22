#ifndef DNLOAD_VIDEOCORE_H
#define DNLOAD_VIDEOCORE_H

#include "bcm_host.h"
#include "EGL/eglplatform.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/** \brief Create native videocore window.
 *
 * \param screen_width Window width.
 * \param screen_height Window height.
 * \param out_native_window Native window output.
 */
static void videocore_create_native_window(int screen_width, int screen_height,
    EGL_DISPMANX_WINDOW_T *out_native_window)
{
  static VC_DISPMANX_ALPHA_T alpha =
  {
    DISPMANX_FLAGS_ALPHA_FIXED_ALL_PIXELS, 255, 0
  };
  VC_RECT_T dst_rect =
  {
    0, 0, screen_width, screen_height
  };
  VC_RECT_T src_rect =
  {
    0, 0, screen_width << 16, screen_height << 16
  };
  DISPMANX_DISPLAY_HANDLE_T dispman_display;
  DISPMANX_UPDATE_HANDLE_T dispman_update;
  DISPMANX_ELEMENT_HANDLE_T dispman_element;

  dnload_bcm_host_init();

  dispman_display = dnload_vc_dispmanx_display_open(0);
  dispman_update = dnload_vc_dispmanx_update_start(0);

  dispman_element = dnload_vc_dispmanx_element_add(dispman_update, dispman_display, 0/*layer*/, &dst_rect, 0/*src*/,
      &src_rect, DISPMANX_PROTECTION_NONE, &alpha, 0/*clamp*/, (DISPMANX_TRANSFORM_T)0/*transform*/);

  out_native_window->element = dispman_element;
  out_native_window->width = screen_width;
  out_native_window->height = screen_height;

  dnload_vc_dispmanx_update_submit_sync(dispman_update);
}

#if defined(__cplusplus)
}
#endif

#endif
