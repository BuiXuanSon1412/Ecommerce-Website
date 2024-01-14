package com.ecomm.web.controller.rest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ecomm.web.service.UserService;

@RestController
public class UserRestController {
    @Autowired
    private UserService userService;
    @PostMapping("/address/delete")
    public String deleteAddress(@RequestParam(name = "aid") Integer addressId) {
        boolean status = userService.deleteAddressById(addressId);
        if(status) return "delete successfully";
        return "Still exist related orders";
    } 
    @PostMapping("/payment/delete")
    public String deletePayment(@RequestParam(name = "pid") Integer paymentId) {
        boolean status = userService.deletePaymentById(paymentId);
        if(status) return "delete successfully";
        return "Still exist related orders";
    }
}
