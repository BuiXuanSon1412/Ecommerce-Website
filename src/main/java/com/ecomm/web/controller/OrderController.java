package com.ecomm.web.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.OrderService;

@Controller
public class OrderController {
    @Autowired
    private OrderService orderService;
    @GetMapping("/order/confirm")
    public String confirmOrder(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<OrderItemDto> orderItems = orderService.findOrderItemsTimeOrderByUserAndCondition(username, "Pending Confirmation");
        model.addAttribute("orderItems", orderItems);
        return "order-confirm";
    }
    @GetMapping("/order/pickup")
    public String pickupOrder(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<OrderItemDto> orderItems = orderService.findOrderItemsTimeOrderByUserAndCondition(username, "Pending Pickup");
        model.addAttribute("orderItems", orderItems);
        return "order-pickup";
    }
    @GetMapping("/order/transit")
    public String transitOrder(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<OrderItemDto> orderItems = orderService.findOrderItemsTimeOrderByUserAndCondition(username, "In Transit");
        model.addAttribute("orderItems", orderItems);
        return "order-transit";
    }
    @GetMapping("/order/deliver")
    public String deliverOrder(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<OrderItemDto> orderItems = orderService.findOrderItemsTimeOrderByUserAndCondition(username, "Delivered");
        model.addAttribute("orderItems", orderItems);
        return "order-deliver";
    }
    @GetMapping("/order/return")
    public String returnOrder(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<OrderItemDto> orderItems = orderService.findOrderItemsTimeOrderByUserAndCondition(username, "Return Initiated");
        model.addAttribute("orderItems", orderItems);
        return "order-return";
    }
    @GetMapping("/order/cancel")
    public String cancelOrder(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<OrderItemDto> orderItems = orderService.findOrderItemsTimeOrderByUserAndCondition(username, "Order Cancelled");
        model.addAttribute("orderItems", orderItems);
        return "order-cancel";
    }
    
}
