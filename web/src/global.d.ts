declare interface WasmExport {
    memory: WebAssembly.Memory;
    blockTextureCount: number;
    blockTextureMapping: number;
    blockTextureBase: number;
    mapInfo: number;
    cameraInfo: number;
    map: number;
    control: number;
    particle: number;
    initEngine(): void;
    deinitEngine(): void;
    initPlayer(): void;
    tick(): void;
    microtick(offset: number): void;
    loadSampleMap(): boolean;
    generateGeomentryDataForChunk(x: number, y: number): number;
}
