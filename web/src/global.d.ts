declare interface WasmExport {
    memory: WebAssembly.Memory;
    mapInfo: number;
    cameraInfo: number;
    exported: number;
    keyboard: number;
    initEngine(): void;
    deinitEngine(): void;
    initPlayer(): void;
    tick(): void;
    loadSampleMap(): void;
    generateGeomentryDataForChunk(x: number, y: number): number;
}
