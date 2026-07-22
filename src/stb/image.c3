module stb::image;

faultdef IMAGE_LOAD_FAILED;

struct Image {
    char* pixels;
    int width;
    int height;
    int channels;
}

extern fn char* stbi_load(char* filename, int* width, int* height, int* channels, int desired_channels) @local;
extern fn char* stbi_load_from_memory(char* buffer, int length, int* width, int* height, int* channels, int desired_channels) @local;
extern fn void stbi_image_free(void* image) @local;
extern fn void stbi_set_unpremultiply_on_load(int enabled) @local;
extern fn void stbi_convert_iphone_png_to_rgb(int enabled) @local;

fn Image? loadFile(String fileName, int channels = 4) {
    Image image;
    image.pixels = stbi_load(
        fileName,
        &image.width,
        &image.height,
        &image.channels,
        channels
    );

    if (!image.pixels) return IMAGE_LOAD_FAILED~;
    if (channels > 0) image.channels = channels;
    return image;
}

fn Image? loadMemory(char[] data, int channels = 4) {
    Image image;
    image.pixels = stbi_load_from_memory(
        data.ptr,
        data.len,
        &image.width,
        &image.height,
        channels
    );

    if (!image.pixels) return IMAGE_LOAD_FAILED~;
    if (channels > 0) image.channels = channels;
    return image;
}

fn void Image.free(&self) {
    if (self.pixels) {
        stbi_image_free(self.pixels);
        self.pixels = null;
    }

    self.width = 0;
    self.height = 0;
    self.channels = 0;
}
