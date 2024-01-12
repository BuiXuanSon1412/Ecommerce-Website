package com.ecomm.web.dto.delivery;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class DeliveryProviderDto {
    private Integer id;
    private String name;

}
