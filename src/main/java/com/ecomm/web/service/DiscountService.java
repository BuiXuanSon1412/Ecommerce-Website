package com.ecomm.web.service;

import java.util.List;

import com.ecomm.web.dto.product.DiscountDto;
import com.ecomm.web.dto.product.ProductDto;

public interface DiscountService {
    public List<DiscountDto> findAllDiscountByUser(String username);
    public void saveDiscount(DiscountDto discountDto);
    public Double productDiscount(ProductDto productDto);
}
