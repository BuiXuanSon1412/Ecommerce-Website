package com.ecomm.web.controller.rest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ecomm.web.service.CartService;

@RestController
public class ShoppingRestController {
    @Autowired
    private CartService cartService;
    @PostMapping("/cart/add")
    public String addToCart(@RequestParam(name = "pid") Integer productId, @RequestParam(name = "qty") Integer quantity) {
        boolean added = cartService.saveCartItem(productId, quantity);
        if(added) return "The item is added to cart successfully";
        return "The item has already been in cart";
    }
    @PostMapping("/cart/remove")
    public String deleteFromCart(@RequestParam(name = "ciid") Integer cartItemId) {
        cartService.deleteCartItemById(cartItemId);
        return "The item is removed";
    }
}
