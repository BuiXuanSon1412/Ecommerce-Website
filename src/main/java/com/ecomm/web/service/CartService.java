package com.ecomm.web.service;

import java.util.List;

import org.springframework.data.util.Pair;

import com.ecomm.web.dto.shopping.CartItemDto;

public interface CartService {
    public boolean saveCartItem(Integer productId, Integer quantity);
    public List<CartItemDto> listCartItems(String username);
    public void deleteCartItemById(Integer cartItemId);
    public Pair<Double, Double> totalAndDiscount(String username);
}
