package com.ecomm.web.mapper;

import com.ecomm.web.dto.store.StoreDto;
import com.ecomm.web.model.store.Store;

public class StoreMapper {
    public static Store mapToStore(StoreDto storeDto) {
        return Store.builder()
                .name(storeDto.getName())
                .description(storeDto.getDescription())
                .build();
    }
    public static StoreDto mapToStoreDto(Store store) {
        return StoreDto.builder()
                .id(store.getId())
                //.user(store.getUser())
                .name(store.getName())
                .build();
    }
}
