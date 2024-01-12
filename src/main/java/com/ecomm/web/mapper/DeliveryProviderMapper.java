package com.ecomm.web.mapper;

import com.ecomm.web.dto.delivery.DeliveryProviderDto;
import com.ecomm.web.model.delivery.DeliveryProvider;

public class DeliveryProviderMapper {
    public static DeliveryProviderDto mapToDeliveryProviderDto(DeliveryProvider deliveryProvider) {
        return DeliveryProviderDto.builder()
                                .id(deliveryProvider.getId())
                                .name(deliveryProvider.getName())
                                .build();
    }
}
