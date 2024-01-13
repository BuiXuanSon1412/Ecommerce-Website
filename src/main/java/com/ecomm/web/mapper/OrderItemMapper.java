package com.ecomm.web.mapper;

import static com.ecomm.web.mapper.ProductMapper.mapToProductDto;

import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.model.shopping.OrderItem;

public class OrderItemMapper {
    public static OrderItemDto mapToOrderItemDto(OrderItem orderItem) {
        return OrderItemDto.builder()
                            .id(orderItem.getId())
                            .product(mapToProductDto(orderItem.getProduct()))
                            .quantity(orderItem.getQuantity())
                            .condition(orderItem.getCondition())
                            .deliveryMethod(orderItem.getDeliveryMethod())
                            .modifiedAt(orderItem.getModifiedAt())      
                            .build();
    }
}
