package com.ecomm.web.controller.rest;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.util.Pair;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.CartService;
import com.ecomm.web.service.OrderService;

@RestController
public class ShoppingRestController {
    @Autowired
    private CartService cartService;
    @Autowired
    private OrderService orderService;
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
    @PostMapping("/cart/update")
    public String updateCart(@RequestParam(name = "ciid") Integer cartItemId, @RequestParam(name = "qty") Integer quantity) {
        Boolean updated = cartService.updateCartItem(cartItemId, quantity);
        if(updated) return "The item is updated successfully";
        return "The item is updatde uncessfully";
    }
    @PostMapping("/pay")
    public ResponseEntity pay(@RequestParam("pid") Integer paymentId, @RequestParam("aid") Integer addressId, @RequestBody List<Pair<Integer, String>> deliveryMethods) {
        String username = SecurityUtil.getSessionUser();
        Boolean isDone = orderService.saveOrderByUser(username, addressId, paymentId, deliveryMethods);
        if(isDone) return ResponseEntity.ok(HttpStatus.OK);
        return ResponseEntity.ok(HttpStatus.BAD_REQUEST);
    }
    
}
