declare interface WasmExport {
    memory: WebAssembly.Memory;
    mapInfo: number;
    cameraInfo: number;
    exported: number;
    control: number;
    initEngine(): void;
    deinitEngine(): void;
    initPlayer(): void;
    tick(): void;
    microtick(offset: number): void;
    loadSampleMap(): void;
    generateGeomentryDataForChunk(x: number, y: number): number;
}
