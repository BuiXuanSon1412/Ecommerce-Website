package com.ecomm.web.mapper;

import static com.ecomm.web.mapper.ProductMapper.mapToProductDto;

import com.ecomm.web.dto.shopping.CartItemDto;
import com.ecomm.web.model.shopping.CartItem;

public class CartItemMapper {
    public static CartItemDto mapToCartItemDto(CartItem cartItem) {
        return CartItemDto.builder()
                            .id(cartItem.getId())
                            .product(mapToProductDto(cartItem.getProduct()))
                            .quantity(cartItem.getQuantity())
                            .build();
    }
}
