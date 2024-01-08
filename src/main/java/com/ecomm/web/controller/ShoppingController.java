package com.ecomm.web.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

import com.ecomm.web.dto.shopping.CartItemDto;
import com.ecomm.web.dto.user.AddressDto;
import com.ecomm.web.dto.user.PaymentDto;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.CartService;
import com.ecomm.web.service.DiscountService;
import com.ecomm.web.service.UserService;



@Controller
public class ShoppingController {
    @Autowired
    private CartService cartService;
    @Autowired
    private DiscountService discountService;
    @Autowired
    private UserService userService;
    @GetMapping("/cart")
    public String viewCart(Model model) {
        List<CartItemDto> cartItems = cartService.listCartItems();
        model.addAttribute("cartItems", cartItems);
        Double total = (double)0;
        Double totalDiscount = (double)0;
        for(CartItemDto cartItem : cartItems) {
            Double totalItem = cartItem.getQuantity() * cartItem.getProduct().getPrice();
            total += totalItem;
            Double disc = discountService.productDiscount(cartItem.getProduct());
            Double totalDiscountItem = total * disc / 100;
            totalDiscount += totalDiscountItem;
        }
        model.addAttribute("total", total);
        model.addAttribute("discount", totalDiscount);
        model.addAttribute("afterDiscount", total - totalDiscount);
        return "shopping-cart";
    }
    @GetMapping("/pay")
    public String checkout(Model model) {
        List<CartItemDto> cartItems = cartService.listCartItems();
        model.addAttribute("cartItems", cartItems);
        String username = SecurityUtil.getSessionUser();
        List<PaymentDto> payments = userService.findPaymentByUser(username);
        model.addAttribute("payments", payments);
        List<AddressDto> addresses = userService.findAddressByUser(username);
        model.addAttribute("addresses", addresses);
        Double total = (double)0;
        Double totalDiscount = (double)0;
        for(CartItemDto cartItem : cartItems) {
            Double totalItem = cartItem.getQuantity() * cartItem.getProduct().getPrice();
            total += totalItem;
            Double disc = discountService.productDiscount(cartItem.getProduct());
            Double totalDiscountItem = total * disc / 100;
            totalDiscount += totalDiscountItem;
        }
        totalDiscount = (double)0;
        model.addAttribute("total", Math.round((total * 100)/100));
        model.addAttribute("discount", Math.round((totalDiscount * 100)/100));
        model.addAttribute("afterDiscount", total - totalDiscount);
        return "shopping-pay";
    }
    /* 
    @PostMapping("/pay")
    public String pay(@RequestParam("address") Integer addressId, @RequestParam("payment") Integer paymentId) {
        String username = SecurityUtil.getSessionUser();
        orderService.saveOrderByUser(username, addressId, paymentId);
        return "shopping-cart";
        */
}
