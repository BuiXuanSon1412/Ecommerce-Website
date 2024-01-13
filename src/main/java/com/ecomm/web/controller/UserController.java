package com.ecomm.web.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.dto.user.AddressDto;
import com.ecomm.web.dto.user.PaymentDto;
import com.ecomm.web.dto.user.Profile;
import com.ecomm.web.dto.user.UserEntityDto;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.UserService;

import jakarta.validation.Valid;

@Controller
public class UserController {
    @Autowired
    private UserService userService;
    @GetMapping("/user/profile")
    public String viewProfile(Model model) {
        UserEntityDto user = userService.findByUsername(SecurityUtil.getSessionUser());
        Profile profile = Profile.builder()
                                .username(user.getUsername())
                                .firstName(user.getFirstName())
                                .lastName(user.getLastName())
                                .telephone(user.getTelephone())
                                .build();
        model.addAttribute("profile", profile);
        return "user-profile";
    }
    @PostMapping("/user/profile")
    public String saveUserProfile(@Valid @ModelAttribute("profile") Profile profile, BindingResult result, Model model){       
        if(result.hasErrors()) {
            model.addAttribute("profile", profile);
            return "profile";
        }
        UserEntityDto newUser = userService.findByUsername(profile.getUsername());
        if(newUser != null 
            && !newUser.getId().equals(userService.findByUsername(SecurityUtil.getSessionUser()).getId())) {
            return "redirect:/user/profile?fail";
        }
        userService.saveProfile(profile);
        return "redirect:/user/profile?success";
    }
    
    @GetMapping("/user/address")
    public String viewAddress(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<AddressDto> addresses = userService.findAddressByUser(username); 
        AddressDto address = AddressDto.builder().build();
        model.addAttribute("address", address);
        model.addAttribute("addresses", addresses);
        return "user-address";
    }

    @PostMapping("/user/address")
    public String saveAddress(@Valid @ModelAttribute("address") AddressDto address, BindingResult result, Model model) {
        String username = SecurityUtil.getSessionUser();
        List<AddressDto> addresses = userService.findAddressByUser(username);
        for(AddressDto a : addresses) {
            if(a.equals(address)) return "/redirect:/user/address";
        }
        userService.saveAddress(address);
        return "redirect:/user/address";
    }
    @GetMapping("/user/payment")
    public String viewPayment(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<PaymentDto> payments = userService.findPaymentByUser(username);
        PaymentDto payment = PaymentDto.builder().build();
        model.addAttribute("payment", payment);
        model.addAttribute("payments", payments);
        return "user-payment";
    }
    @PostMapping("/user/payment")
    public String savePayment(@Valid @ModelAttribute("payment") PaymentDto payment, BindingResult result, Model model) {
        String username = SecurityUtil.getSessionUser();
        List<PaymentDto> payments = userService.findPaymentByUser(username);
        for(PaymentDto p : payments) {
            if(p.equals(payment)) return "/redirect:/user/payment";
        }
        userService.savePayment(payment);
        return "redirect:/user/payment";
    }

    @GetMapping("/user/purchase")
    public String viewPurchase(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<OrderItemDto> orderItems = userService.findPurchasesByUser(username);
        model.addAttribute("orderItems", orderItems);
        return "user-purchase";
    }
    @PostMapping("/address/delete")
    public String deleteAddress(@RequestParam(name = "aid") Integer addressId) {
        userService.deleteAddressById(addressId);
        return "redirect:/user/address";
    } 
    @PostMapping("/payment/delete")
    public String deletePayment(@RequestParam(name = "pid") Integer paymentId) {
        userService.deletePaymentById(paymentId);
        return "redirect:/user/address";
    }
}
