declare interface WasmExport {
    memory: WebAssembly.Memory;
    mapInfo: number;
    cameraInfo: number;
    initEngine(): boolean;
    deinitEngine(): void;
    initPlayer(): void;
    tick(): void;
    loadSampleMap(): void;
    generateGeomentryDataForChunk(x: number, y: number): number;
}
