import { IsString, IsObject, IsOptional, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

class MessageDto {
  @IsString()
  data: string; // Base64 encoded JSON

  @IsString()
  messageId: string;

  @IsString()
  publishTime: string;

  @IsOptional()
  @IsObject()
  attributes?: Record<string, string>;
}

export class PubSubMessageDto {
  @ValidateNested()
  @Type(() => MessageDto)
  message: MessageDto;

  @IsString()
  subscription: string;
}
