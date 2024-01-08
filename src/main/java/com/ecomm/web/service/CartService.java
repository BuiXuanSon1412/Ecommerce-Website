package com.ecomm.web.service;

import java.util.List;

import com.ecomm.web.dto.shopping.CartItemDto;

public interface CartService {
    public boolean saveCartItem(Integer productId, Integer quantity);
    public List<CartItemDto> listCartItems();
    public void deleteCartItemById(Integer cartItemId);
}
