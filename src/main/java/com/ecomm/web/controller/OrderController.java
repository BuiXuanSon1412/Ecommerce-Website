package com.ecomm.web.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import com.ecomm.web.dto.delivery.DeliveryProviderDto;
import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.OrderService;
import com.ecomm.web.service.StoreService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;


@Controller
public class OrderController {
    @Autowired
    private OrderService orderService;
    @Autowired
    private StoreService storeService;
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
        List<DeliveryProviderDto> deliveryProviders = storeService.findAll();
        List<OrderItemDto> orderItems = orderService.findOrderItemsTimeOrderByUserAndCondition(username, "Pending Pickup");
        List<OrderItemDto> orderItems_ = orderService.findOrderItemsTimeOrderByUserAndCondition(username, "Completed Setup");
        for(OrderItemDto  oi : orderItems_) {
            orderItems.add(oi);
        }
        model.addAttribute("deliveryProviders", deliveryProviders);
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
    @PostMapping("/order/prepare")
    public String updateOrder(@RequestParam("dpid") Integer dpid, @RequestParam(name = "oiid") Integer oiid) {
        boolean status = orderService.prepareOrder(dpid, oiid);
        return "redirect:/order/pickup";
    }
    
    
    
}
