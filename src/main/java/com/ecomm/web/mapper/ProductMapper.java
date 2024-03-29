package com.ecomm.web.mapper;

import com.ecomm.web.dto.product.AddProductForm;
import com.ecomm.web.dto.product.ProductDto;
import com.ecomm.web.model.product.Product;

import static com.ecomm.web.mapper.StoreMapper.mapToStoreDto;

import org.springframework.beans.factory.annotation.Autowired;

import static com.ecomm.web.mapper.DiscountMapper.mapToDiscountDto;

public class ProductMapper {
    @Autowired
    public static ProductDto mapToProductDto(Product product) {
        if(product == null) return null;
        return ProductDto.builder()
                .id(product.getId())
                .name(product.getName())
                .store(mapToStoreDto(product.getStore()))
                .desc(product.getDesc())
                .image(product.getImage())
                .sku(product.getSku())
                .price(product.getPrice())
                .discount(mapToDiscountDto(product.getDiscount()))
                .build();
    }
    public static Product mapToProduct(ProductDto productDto) {
        return Product.builder()
                .name(productDto.getName())
                .desc(productDto.getDesc())
                .image(productDto.getImage())
                .sku(productDto.getSku())
                .price(productDto.getPrice())
                .build();
    }
    public static Product mapFromAddProductFormToProduct(AddProductForm product) {
        return Product.builder()
                .name(product.getName())
                .desc(product.getDesc())
                .image(product.getImage())
                .sku(product.getSku())
                .price(product.getPrice())
                .build();
    }
}
