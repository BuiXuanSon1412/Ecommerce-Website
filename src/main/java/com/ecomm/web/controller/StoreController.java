package com.ecomm.web.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;

import com.ecomm.web.dto.product.AddProductForm;
import com.ecomm.web.dto.product.CategoriesDto;
import com.ecomm.web.dto.product.CategoryDto;
import com.ecomm.web.dto.product.DiscountDto;
import com.ecomm.web.dto.product.ProductDto;
import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.dto.store.StoreDto;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.CategoryService;
import com.ecomm.web.service.DiscountService;
import com.ecomm.web.service.OrderService;
import com.ecomm.web.service.ProductService;
import com.ecomm.web.service.StoreService;

import jakarta.validation.Valid;

@Controller
public class StoreController {
    @Autowired
    private StoreService storeService;
    @Autowired
    private OrderService orderService;
    @Autowired
    private ProductService productService;
    @Autowired
    private DiscountService discountService;
    @Autowired
    private CategoryService categoryService;

    @GetMapping("/store/register")
    public String registerStore(Model model) {
        StoreDto store = StoreDto.builder().build();
        model.addAttribute("store", store);
        return "store-register";
    }

    @PostMapping("/store/register")
    public String registerStore(@Valid @ModelAttribute("store") StoreDto storeDto, BindingResult result, Model model) {
        if (result.hasErrors()) {
            model.addAttribute("store", storeDto);
            return "store-register";
        }
        storeService.registerStore(storeDto);
        return "redirect:/store/dashboard";
    }

    @GetMapping("/store/profile")
    public String editStore(Model model) {
        return "store-profile";
    }

    @GetMapping("/store/dashboard")
    public String dashboardStore() {
        return "store-dashboard";
    }

    @GetMapping("/store/order")
    public String allOrder(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<OrderItemDto> orderItems = orderService.findOrderItemsTimeOrderByUser(username);
        model.addAttribute("orderItems", orderItems);
        return "store-order";
    }
    @GetMapping("/store/discount")
    public String listDiscount(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<DiscountDto> discounts = discountService.findAllDiscountByUser(username);
        DiscountDto discount = DiscountDto.builder().build();
        model.addAttribute("discounts", discounts);
        model.addAttribute("discount", discount);
        return "store-discount";
    }

    @PostMapping("/store/discount")
    public String addDiscount(@Valid @ModelAttribute("discount") DiscountDto discount, BindingResult result,
            Model model) {
        String username = SecurityUtil.getSessionUser();
        List<DiscountDto> discounts = discountService.findAllDiscountByUser(username);
        for (DiscountDto d : discounts) {
            if (d.equals(discount))
                return "/redirect:/store/discount";
        }
        discountService.saveDiscount(discount);
        return "redirect:/store/discount";
    }

    @GetMapping("/store/product")
    public String listProduct(Model model) {
        String username = SecurityUtil.getSessionUser();
        List<ProductDto> products = productService.findProductByUser(username);
        AddProductForm product = AddProductForm.builder().build();
        List<CategoriesDto> categories = categoryService.findAllLevelCategories();
        model.addAttribute("product", product);
        model.addAttribute("products", products);
        model.addAttribute("categories", categories);
        return "store-product";
    }

    @PostMapping("/store/product")
    public String addProduct(@Valid @ModelAttribute("product") AddProductForm addProductForm, BindingResult result,
            Model model) {
        if (result.hasErrors()) {
            //model.addAttribute("product", addProductForm);
            String username = SecurityUtil.getSessionUser();
            List<ProductDto> products = productService.findProductByUser(username);
            //AddProductForm product = AddProductForm.builder().build();
            List<CategoryDto> categories = categoryService.findAllBaseCategories();
            model.addAttribute("product", addProductForm);
            model.addAttribute("products", products);
            model.addAttribute("categories", categories);
            return "store-product";
        }
        productService.saveProduct(addProductForm);
        return "redirect:/store/product";
    }
    @GetMapping("/store/delivery")
    public String deliverySetting(Model model) {
        return "store-delivery";
    }
}
