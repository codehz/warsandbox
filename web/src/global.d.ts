declare interface WasmExport {
    memory: WebAssembly.Memory;
    mapInfo: number;
    cameraInfo: number;
    initRegistry(): void;
    deinitRegistry(): void;
    initPlayer(): void;
    tick(): void;
    loadSampleMap(): void;
    generateGeomentryDataForChunk(x: number, y: number): number;
}
