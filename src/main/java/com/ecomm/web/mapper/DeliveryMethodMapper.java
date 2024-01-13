package com.ecomm.web.mapper;

import static com.ecomm.web.mapper.StoreMapper.mapToStoreDto;

import com.ecomm.web.dto.store.DeliveryMethodDto;
import com.ecomm.web.model.store.DeliveryMethod;

public class DeliveryMethodMapper {
    public static DeliveryMethodDto mapToDeliveryMethodDto(DeliveryMethod deliveryMethod) {
        return DeliveryMethodDto.builder()
                                    .id(deliveryMethod.getId())
                                    .store(mapToStoreDto(deliveryMethod.getStore()))
                                    .methodName(deliveryMethod.getMethodName())
                                    .price(deliveryMethod.getPrice())
                                    .isActive(deliveryMethod.getIsActive())
                                    .build();
    }
}
