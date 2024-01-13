package com.ecomm.web.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.util.Pair;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import com.ecomm.web.dto.shopping.CartItemDto;
import com.ecomm.web.dto.user.AddressDto;
import com.ecomm.web.dto.user.PaymentDto;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.CartService;
import com.ecomm.web.service.UserService;



@Controller
public class ShoppingController {
    @Autowired
    private CartService cartService;
    @Autowired
    private UserService userService;
    @GetMapping("/cart")
    public String viewCart(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<CartItemDto> cartItems = cartService.listCartItems(username);
        model.addAttribute("cartItems", cartItems);
        Pair<Double, Double> td = cartService.totalAndDiscount(username);
        model.addAttribute("total", td.getFirst());
        model.addAttribute("discount", td.getSecond());
        model.addAttribute("afterDiscount", td.getFirst() - td.getSecond());
        return "shopping-cart";
    }
    @GetMapping("/pay")
    public String checkout(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<CartItemDto> cartItems = cartService.listCartItems(username);
        model.addAttribute("cartItems", cartItems);
        List<PaymentDto> payments = userService.findPaymentByUser(username);
        model.addAttribute("payments", payments);
        List<AddressDto> addresses = userService.findAddressByUser(username);
        model.addAttribute("addresses", addresses);
        Pair<Double, Double> td = cartService.totalAndDiscount(username);
        model.addAttribute("total", td.getFirst());
        model.addAttribute("discount", td.getSecond());
        model.addAttribute("afterDiscount", td.getFirst() - td.getSecond());
        return "shopping-pay";
    }
    
}
