package com.ecomm.web.mapper;

import static com.ecomm.web.mapper.ProductMapper.mapToProductDto;

import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.model.shopping.OrderItem;

public class OrderItemMapper {
    public static OrderItemDto mapToOrderItemDto(OrderItem orderItem) {
        return OrderItemDto.builder()
                            .product(mapToProductDto(orderItem.getProduct()))
                            .quantity(orderItem.getQuantity())
                            //.paymentType(orderItem.getOrderDetail().getPayment().getPaymentType())
                            .condition(orderItem.getCondition())                    
                            .build();
    }
}
